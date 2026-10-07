#!/usr/bin/env bash
# Prefix every workspace label with its sidebar number, e.g. "[3] dotfiles".
#
# The script is idempotent: it strips an old prefix, adds the current one, and
# renames only the workspaces whose label changed. Its own renames emit
# workspace.renamed, which runs the script again as a no-op. If two runs race
# (a burst of events), the last rename emits workspace.renamed again, so the
# labels converge on the final order.
set -eu

herdr=${HERDR_BIN_PATH:-herdr}

"$herdr" workspace list |
	jq -r '.result.workspaces[]
		| (.label | sub("^\\[[0-9]+\\] "; "")) as $base
		| "[\(.number)] \($base)" as $want
		| select(.label != $want)
		| [.workspace_id, $want] | @tsv' |
	while IFS=$'\t' read -r id label; do
		"$herdr" workspace rename "$id" "$label" >/dev/null
	done
