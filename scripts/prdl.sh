prdl() {
  # ─── Usage ───────────────────────────────────────────────────────────────────
  _gh_dl_pr_artifacts_usage() {
    cat >&2 <<'EOF'
PR Download - downloads artifacts from your PR's workflow runs
Usage: prdl [OPTIONS]

Options:
  --branch   <name>   Branch to look up (default: current git branch)
  --run-id   <id>     Workflow run ID (default: latest run for branch)
  --workflow <name>   Workflow name to filter by (default: CI)
  --out-dir  <path>   Output root directory (default: /tmp/gh_artifacts)
  --all               Skip artifact selection and download everything
  -h, --help          Show this help
EOF
  }

  # ─── Argument parsing ────────────────────────────────────────────────────────
  local opt_branch="" opt_run_id="" opt_workflow="CI"
  local opt_out_dir="" opt_all=false

  while (( $# )); do
    case "$1" in
      --branch)   opt_branch="$2";   shift 2 ;;
      --run-id)   opt_run_id="$2";   shift 2 ;;
      --workflow) opt_workflow="$2"; shift 2 ;;
      --out-dir)  opt_out_dir="$2";  shift 2 ;;
      --all)      opt_all=true;      shift   ;;
      -h|--help)  _gh_dl_pr_artifacts_usage; return 0 ;;
      *) echo "❌  Unknown option: $1" >&2; _gh_dl_pr_artifacts_usage; return 1 ;;
    esac
  done

  # ─── Dependency checks ───────────────────────────────────────────────────────
  local missing=()
  for cmd in gh git jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if (( ${#missing[@]} )); then
    echo "❌  Missing required tools: ${missing[*]}" >&2
    return 1
  fi

  local use_fzf=false
  command -v fzf &>/dev/null && use_fzf=true

  # ─── Branch ──────────────────────────────────────────────────────────────────
  local branch="$opt_branch"
  if [[ -z "$branch" ]]; then
    branch=$(git branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && { echo "❌  Not in a git repo or HEAD - Can't determine github repository" >&2; return 1; }
  fi

  # ─── PR ──────────────────────────────────────────────────────────────────────
  echo "🔍  Looking up PR for branch '${branch}'..."
  local pr_json
  pr_json=$(gh pr view "$branch" --json number,headRefName 2>/dev/null) \
    || { echo "❌  No open PR found for branch '${branch}'." >&2; return 1; }

  local pr_number
  pr_number=$(jq -r '.number' <<< "$pr_json")
  echo "📌  PR #${pr_number}"

  # ─── Workflow run ─────────────────────────────────────────────────────────────
  local run_id="$opt_run_id"
  local attempt workflow_name conclusion

  if [[ -n "$run_id" ]]; then
    echo "🔍  Fetching run #${run_id}..."
    local run_json
    run_json=$(
      gh run view "$run_id" \
        --json databaseId,displayTitle,status,conclusion,workflowName,attempt,startedAt \
        2>/dev/null
    ) || { echo "❌  Could not fetch run #${run_id}." >&2; return 1; }

    attempt=$(jq -r '.attempt'        <<< "$run_json")
    workflow_name=$(jq -r '.workflowName'   <<< "$run_json")
    conclusion=$(jq -r '.conclusion'   <<< "$run_json")
    run_started_at=$(jq -r '.startedAt' <<< "$run_json")
  else
    echo "🔍  Fetching latest '${opt_workflow}' run for branch '${branch}'..."
    local run_json
    run_json=$(
      gh run list \
        --branch "$branch" \
        --workflow "$opt_workflow" \
        --limit 1 \
        --json databaseId,displayTitle,status,conclusion,workflowName,attempt,startedAt \
        2>/dev/null | jq '.[0]'
    )

    [[ -z "$run_json" || "$run_json" == "null" ]] && {
      echo "❌  No '${opt_workflow}' runs found for branch '${branch}'." >&2
      return 1
    }

    run_id=$(jq -r '.databaseId'     <<< "$run_json")
    attempt=$(jq -r '.attempt'         <<< "$run_json")
    workflow_name=$(jq -r '.workflowName'    <<< "$run_json")
    conclusion=$(jq -r '.conclusion'    <<< "$run_json")
    run_started_at=$(jq -r '.startedAt' <<< "$run_json")
  fi

  echo "⚙️   Workflow   : ${workflow_name}"
  echo "    Run ID     : ${run_id}"
  echo "    Attempt    : #${attempt}"
  echo "    Status     : ${conclusion}"
  echo "    Started at : ${run_started_at}"

  # ─── Jobs (fetched once — used for failure summary + artifact correlation) ────
  echo ""
  echo "🔍  Checking for failed jobs..."
  local all_jobs_json
  all_jobs_json=$(
    gh run view "$run_id" --json jobs \
      | jq '[.jobs[] | {name: .name, conclusion: .conclusion, startedAt: .startedAt, completedAt: .completedAt}]'
  )

  # ─── Artifacts for the run ───────────────────────────────────────────────────
  echo ""
  echo "🔍  Fetching artifacts for run #${run_id}..."
  local repo
  repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

  # --paginate emits one JSON envelope per page; -s slurps + flattens them all.
  # Keep only artifacts whose created_at is after the run's startedAt so that
  # leftover artifacts from earlier attempts are excluded.
  # Each artifact is then matched to the job whose completedAt is closest to
  # the artifact's created_at — the best proxy available for "who uploaded this"
  # when jobs run in parallel (a job's final act is uploading its artifacts, so
  # its completedAt and the artifact's created_at are nearly identical).
  local artifacts_json
  artifacts_json=$(
    gh api --paginate "repos/${repo}/actions/runs/${run_id}/artifacts" \
      | jq -s --arg since "$run_started_at" --argjson jobs "$all_jobs_json" '
          [.[].artifacts[]
            | select(.created_at > $since)
            | {id: .id, name: .name, size_in_bytes: .size_in_bytes, created_at: .created_at}]
          | map(
              . as $art |
              ($art.created_at | fromdateiso8601) as $art_ts |
              (
                $jobs
                | map(
                    ((.completedAt // "9999-12-31T23:59:59Z") | fromdateiso8601) as $ct |
                    { name:       .name,
                      conclusion: .conclusion,
                      diff:       ($ct - $art_ts | if . < 0 then -. else . end) }
                  )
                | sort_by(.diff)
                | first
              ) as $closest |
              $art + {
                job_name:       ($closest.name       // "unknown"),
                job_conclusion: ($closest.conclusion // "unknown")
              }
            )
          | sort_by([.job_conclusion, .created_at])'
  )
  local artifact_count
  artifact_count=$(jq 'length' <<< "$artifacts_json")

  if (( artifact_count == 0 )); then
	  echo "ℹ️   No artifacts found for run #${run_id} (after ${run_started_at})."
    return 0
  fi

  # Tab-separated lines — field order as requested:
  #   1:id  2:name  3:job_conclusion  4:icon  5:job_name  6:created_at
  # Keeping job_conclusion as a plain word lets fzf filter by typing
  # "failure" or "success". Built once, reused for listing + fzf + fallback.
  local fzf_lines
  fzf_lines=$(
    jq -r '.[] |
      (.job_conclusion | if . == "failure" then "❌" elif . == "success" then "✅" else "❔" end) as $icon |
      "\(.id)\t\(.name)\t\(.job_conclusion)\t\($icon)\t\(.job_name)\t\(.created_at)"
    ' <<< "$artifacts_json"
  )

  echo "📦  Artifacts created after run start (${artifact_count}):"
  while IFS=$'\t' read -r id name conclusion icon job_name created_at; do
    printf "     %s  %-45s  %s %-10s  %-50s  %s\n" \
      "$id" "$name" "$icon" "$conclusion" "$job_name" "$created_at"
  done <<< "$fzf_lines"

  # ─── Artifact selection ──────────────────────────────────────────────────────
  echo ""
  # Each entry is "id\tname" — id drives the API download, name drives the dest path.
  local all_pairs
  all_pairs=$(jq -r '.[] | "\(.id)\t\(.name)"' <<< "$artifacts_json")

  local selected_pairs
  if $opt_all; then
    echo "⏩  --all flag set, selecting all artifacts."
    selected_pairs="$all_pairs"
  elif $use_fzf; then
    # ALL sentinel: field 1 = "[ ALL ]" so cut -f1 can detect it reliably.
    local raw_selection
    raw_selection=$(
      { printf '[ ALL ]\t[ ALL ]\t\t—\t— download all artifacts\t\n'; echo "$fzf_lines"; } \
        | fzf --multi \
              --delimiter=$'\t' \
              --prompt="Artifacts ❯ " \
              --header="TAB = multi-select   ENTER = confirm   (type 'failure'/'success' to filter)"
    )
    [[ -z "$raw_selection" ]] && { echo "No artifacts selected. Aborting."; return 0; }

    if cut -f1 <<< "$raw_selection" | grep -qxF "[ ALL ]"; then
      selected_pairs="$all_pairs"
    else
      # Fields 1-2 are artifact id and name
      selected_pairs=$(cut -f1,2 <<< "$raw_selection")
    fi
  else
    # Plain numbered list fallback
    echo "Select artifacts:"
    local i=1 pairs_array=()
    while IFS=$'\t' read -r id name conclusion icon job_name created_at; do
      printf "  %2d) %-45s  %s %-10s  %s  [%s]\n" \
        "$i" "$name" "$icon" "$conclusion" "$job_name" "$created_at"
      pairs_array+=("${id}"$'\t'"${name}")
      (( i++ ))
    done <<< "$fzf_lines"
    echo ""
    printf "Enter numbers separated by spaces, or 'a' for all: "
    local reply
    read -r reply

    if [[ "$reply" == [aA] ]]; then
      selected_pairs="$all_pairs"
    else
      selected_pairs=""
      for num in $reply; do
        local idx=$(( num - 1 ))
        if (( idx >= 0 && idx < ${#pairs_array[@]} )); then
          selected_pairs+="${pairs_array[$idx]}"$'\n'
        else
          echo "⚠️   Ignoring out-of-range index: ${num}" >&2
        fi
      done
    fi
  fi

  [[ -z "$selected_pairs" ]] && { echo "No artifacts selected. Aborting."; return 0; }

  # ─── Download ────────────────────────────────────────────────────────────────
  local out_root="${opt_out_dir:-/tmp/gh_artifacts}"
  local dest_base="${out_root}/${pr_number}/${run_id}/${attempt}"

  echo ""
  echo "📥  Saving to: ${dest_base}"
  mkdir -p "$dest_base"

  local all_downloaded=()

  while IFS=$'\t' read -r artifact_id artifact_name; do
    [[ -z "$artifact_id" ]] && continue

    local dest_dir="${dest_base}/${artifact_name}"

    echo ""

	if [ -d "$dest_dir" ]; then
		echo "⚠️   Directory exists, skipping... (${dest_dir})"
		all_downloaded+=("$dest_dir")
		continue
	else
		mkdir -p "$dest_dir"
	fi

    echo "⬇️   Downloading '${artifact_name}' (id: ${artifact_id})..."
    if ! gh api "repos/${repo}/actions/artifacts/${artifact_id}/zip" > "${dest_dir}/${artifact_name}.zip"; then
      echo "⚠️   Failed to download '${artifact_name}'." >&2
      continue
    fi

    # Unzip the downloaded archive in-place
    while IFS= read -r zipfile; do
      echo "📂  Unzipping '$(basename "$zipfile")'..."
      unzip -o "$zipfile" -d "$(dirname "$zipfile")" > /dev/null
      rm -f "$zipfile"
    done < <(find "$dest_dir" -name "*.zip" -type f)

    # Record the artifact directory itself
    all_downloaded+=("$dest_dir")

  done <<< "$selected_pairs"

  # ─── Summary ─────────────────────────────────────────────────────────────────
  echo ""
  if (( ${#all_downloaded[@]} == 0 )); then
    echo "⚠️   Nothing was downloaded."
    return 1
  fi

  echo "✅  Downloaded artifact directories:"
  for dir in "${all_downloaded[@]}"; do
    if command -v realpath &>/dev/null; then
      echo "    $(realpath "$dir")"
    else
      echo "    $(cd "$dir" && pwd)"
    fi
  done

  local traces
  traces=$(find "${dest_base}/" -name "trace.zip" -type f)

  if [ -n "$traces" ]; then
	  echo ""
	  echo "✅  Traces found:"
	  echo $traces
  else
    echo "⚠️   No traces found"
  fi
}
