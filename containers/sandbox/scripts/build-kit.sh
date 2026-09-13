#!/usr/bin/env bash
#
# Runs on the HOST from `devbox`, before the sandbox is created.
#
# Writes the per-workspace *kit* — the one declarative artifact that carries
# everything this workspace needs into its sandbox:
#
#   $DEVBOX_STATE/kit/
#     spec.yaml                     the kit itself (schema v2, kind: mixin)
#     files/home/.claude/skills/    your host skills, agents and CLAUDE.md,
#     files/home/.claude/agents/    copied out by stage-claude-config.sh
#     files/home/.claude/CLAUDE.md
#
# `devbox` passes it as `sbx create --kit`, which merges it into the built-in
# `claude` kit: the allow lists union, the environments merge, the setup commands
# concatenate. That merge is what the old docker-compose.overrides.yml did, and
# it is why this is one script rather than the twelve host-side hooks it
# replaces — sbx composes kits itself, so nothing here has to.
#
# What goes in it, and where each part comes from:
#
#   permissions.network.allow   ../allowed-domains
#                               ../projects/<profile>/allowed-domains
#                               $DEVBOX_ALLOW_DOMAINS
#   environment.variables       the shared caches, $DEVBOX_TOOLS, the telemetry,
#                               ../projects/<profile>/env and env.local,
#                               your git identity (init-git-identity.sh)
#   credentials                 GitHub, resolved from the host secret store
#   setup.install               ../projects/<profile>/setup.sh
#   volumes                     GitNexus's index, off the workspace bind mount
#
# The shared caches are NOT here: a kit volume is block or tmpfs storage inside
# the VM, never a host directory, so a cache that has to be shared by every
# workspace is a host path `devbox` passes as an extra read-write workspace.
# See ensure-caches.sh.
#
# Rebuilt from scratch on every `up`, so removing a line from a profile removes
# it from the sandbox on the next create. Built beside the target and swapped, so
# an interrupted run cannot leave half a kit behind.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/profile.sh"

home="$(cd "$here/.." && pwd)"
workspace="${DEVBOX_WORKSPACE:?}"
profile="${DEVBOX_PROFILE:?}"
state="${DEVBOX_STATE:?}"
tools="${DEVBOX_TOOLS:?}"
caches="${DEVBOX_CACHES:?}"

dir="$(profile_dir "$profile")"
out="$state/kit"
tmp="$out.tmp.$$"

log() { printf '\033[1;34m[kit]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[kit] WARNING:\033[0m %s\n' "$1" >&2; }

rm -rf "$tmp"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

# YAML double-quoted scalars take backslash escapes, so both characters have to
# be escaped and in that order. Every value below goes through this — a profile's
# `env` holds URLs and passwords, and a Windows-style path in one would otherwise
# produce a spec that does not parse.
yaml_escape() {
	local s="$1"
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	printf '%s' "$s"
}

# --- The egress allowlist -----------------------------------------------------
#
# `#` comments and blank lines out, whitespace trimmed, duplicates dropped. The
# entries themselves are passed through as written: sbx accepts an exact host, a
# host:port, a `*.example.com` single-label wildcard and a CIDR, which is a
# superset of what the old ipset firewall took, so no file needed rewriting.
#
# Enforcement is the sandbox runtime's, outside the VM. It is only default-deny
# if the machine's global policy is — `devbox` checks that and says so.
read_domains() {
	local file="$1" line
	[ -f "$file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[ -n "$line" ] && printf '%s\n' "$line"
	done <"$file"
	return 0
}

domains="$(
	{
		read_domains "$home/allowed-domains"
		read_domains "$dir/allowed-domains"
		printf '%s' "${DEVBOX_ALLOW_DOMAINS:-}" | tr ', ' '\n\n'
	} | grep -v '^$' | sort -u
)"

# --- The environment ----------------------------------------------------------
#
# KEY=VALUE lines on stdin, `KEY: "value"` on stdout. Everything that wants to
# contribute environment emits the first shape, so a profile's `env` file, the
# git identity script and the block below all go through one converter.
#
# Three placeholders are substituted in the value, because the paths they stand
# for are per-workspace or per-user and no checked-in file can name them:
#
#   %WORKSPACE%  the checkout (the same path on the host and in the sandbox)
#   %TOOLS%      this profile's durable scratch (= $DEVBOX_TOOLS)
#   %CACHES%     the directory the shared caches live in (= $DEVBOX_CACHES)
#
# Substitution and not shell expansion: a profile's `env` is data, and eval-ing
# it would make a profile a second place where arbitrary host commands run.
emit_env() {
	local line key value
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in '' | '#'*) continue ;; esac
		# Comments only on their own line: a `#` inside a value is a legitimate
		# character (URLs, passwords) and stripping it would corrupt the value.
		[ "$line" != "${line#*=}" ] || {
			warn "ignoring line without '=': $line"
			continue
		}
		key="${line%%=*}"
		value="${line#*=}"
		key="${key#"${key%%[![:space:]]*}"}"
		key="${key%"${key##*[![:space:]]}"}"
		key="${key#export }"
		# Strip one layer of matching quotes, the way an .env file is usually
		# written; the value is re-quoted for YAML either way.
		case "$value" in
		\'*\') value="${value#\'}" value="${value%\'}" ;;
		\"*\") value="${value#\"}" value="${value%\"}" ;;
		esac
		value="${value//%WORKSPACE%/$workspace}"
		value="${value//%TOOLS%/$tools}"
		value="${value//%CACHES%/$caches}"
		printf '    %s: "%s"\n' "$key" "$(yaml_escape "$value")"
	done
}

# The variables that describe this workspace to whatever runs in the sandbox, and
# the ones that point each toolchain at its shared cache.
#
# Every path here is a HOST path, unchanged: sbx mounts a workspace at the same
# absolute path it has on the host, so ~/.cache/devbox/turbo is that same string
# inside the VM. That is what removes the whole /workspaces/<slug> remapping the
# devcontainer needed, and with it every chown of a named volume's mount point.
#
# `DEVBOX_` is not one of the prefixes the runtime reserves (`SBX_`, `DASH_`,
# `DOCKER_`), so these names are ours to set.
devbox_env() {
	cat <<-ENV
		DEVBOX_HOME=$home
		DEVBOX_WORKSPACE=$workspace
		DEVBOX_PROFILE=$profile
		DEVBOX_TOOLS=$tools
		YARN_ENABLE_GLOBAL_CACHE=true
		YARN_GLOBAL_FOLDER=$caches/yarn-berry
		TURBO_CACHE_DIR=$caches/turbo
		PLAYWRIGHT_BROWSERS_PATH=$caches/ms-playwright
	ENV
}

# Claude Code's metrics, events and spans, pushed to the machine's observability
# stack (../../observability/). `host.docker.internal`, not the collector's
# container name: the sandbox is a VM with its own network namespace and its own
# Docker daemon, so the `observability` bridge network the devcontainer joined is
# not reachable from in here and no name on it resolves.
#
# https://code.claude.com/docs/en/monitoring-usage
telemetry_env() {
	cat <<-ENV
		CLAUDE_CODE_ENABLE_TELEMETRY=1
		OTEL_METRICS_EXPORTER=otlp
		OTEL_LOGS_EXPORTER=otlp
		OTEL_LOG_TOOL_DETAILS=1
		CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
		OTEL_TRACES_EXPORTER=otlp
		OTEL_EXPORTER_OTLP_PROTOCOL=grpc
		OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317
		OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
		OTEL_METRIC_EXPORT_INTERVAL=10000
		OTEL_RESOURCE_ATTRIBUTES=workspace=$workspace,devbox.profile=$profile
	ENV
}

environment="$(
	{
		devbox_env
		telemetry_env
		bash "$here/init-git-identity.sh"
		[ -f "$dir/env" ] && cat "$dir/env"
		# Layered on top and gitignored, for anything secret — a license key, a
		# token — that has no business in a dotfiles repo. Later wins, so it can
		# also override a value from `env`.
		[ -f "$dir/env.local" ] && cat "$dir/env.local"
		true
	} | emit_env
)"

# --- Setup ---------------------------------------------------------------------
#
# `setup.install` runs once, at create, before the agent launches. Every entry
# here runs as uid 1000, which the spec's default (root) is not: the workspace,
# $DEVBOX_TOOLS and every shared cache belong to the agent user, and a root-owned
# file in any of them breaks the next install.
#
# One behaviour change worth knowing: a profile's setup now runs *behind* the
# allowlist. Under the devcontainer, setup.sh ran at updateContentCommand and the
# firewall was applied after it, so a profile could download from anywhere. Here
# there is no unrestricted window — a host a profile's install needs belongs in
# that profile's allowed-domains.
setup_install() {
	# Your git identity, turned into real config so `git config user.email`
	# answers and a repo-local identity set inside the sandbox still wins. Safe to
	# run unconditionally: /home/agent is the image's, not a volume, so this hits
	# a fresh ~/.gitconfig on every create.
	#
	# gc.worktreePruneExpire is the safety belt for a linked worktree. The sandbox
	# can see the shared git dir but not the *other* worktrees' host paths, so
	# from in here they all look like they "point to a non-existent location" and
	# become prune candidates once past the default three months — and a routine
	# `git gc` would then unregister worktrees that are perfectly healthy on the
	# host. This covers `git gc`/`gc --auto`, which pass the value through as
	# --expire. It does NOT cover an explicit `git worktree prune`, which defaults
	# to expiring everything and ignores the config. Don't run that in here.
	# `if` and not `[ … ] && …`: an install command is run by `sh -c` and this one
	# sets -e, where a bare test that comes out false is a failed statement — so
	# the short form would abort the step for the ordinary case of an unset
	# identity, taking the gc setting below with it.
	cat <<-'YAML'
		    - command: |
		        set -e
		        if [ -n "${DEVBOX_GIT_USER_NAME:-}" ]; then
		          git config --global user.name "$DEVBOX_GIT_USER_NAME"
		        fi
		        if [ -n "${DEVBOX_GIT_USER_EMAIL:-}" ]; then
		          git config --global user.email "$DEVBOX_GIT_USER_EMAIL"
		        fi
		        git config --global gc.worktreePruneExpire never
		      user: "1000"
		      description: "git identity and worktree-safe gc"
	YAML

	# The profile's own setup: install dependencies, fetch a toolchain into
	# $DEVBOX_TOOLS, generate whatever the repo needs before it can build. Nothing
	# is assumed about the workspace — a profile with no setup.sh (`default`,
	# unless you give it one) leaves you with the bare toolchain image and a
	# shell.
	#
	# Via `bash` because the exec bit comes from a read-only host mount and can't
	# be relied on.
	if [ -f "$dir/setup.sh" ]; then
		cat <<-YAML
			    - command: "cd '$(yaml_escape "$workspace")' && bash '$(yaml_escape "$dir/setup.sh")'"
			      user: "1000"
			      description: "profile setup: projects/$profile/setup.sh"
		YAML
	fi

	# After the profile, so it can rely on the workspace's node_modules — which is
	# how it gets at the Playwright version the repo pins rather than one of its
	# own. A no-op in a workspace that has no Playwright.
	cat <<-YAML
		    - command: "bash '$(yaml_escape "$here/install-playwright-browsers.sh")'"
		      user: "1000"
		      description: "playwright browsers, into the shared cache"
	YAML
}

# --- Writing the spec ---------------------------------------------------------

{
	echo 'schemaVersion: "2"'
	echo 'kind: mixin'
	# One name per profile, not per workspace: the name has to match
	# ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ and be unique within a composition,
	# and only one of these is ever composed at a time.
	echo "name: devbox-$profile"
	echo "displayName: \"devbox ($profile)\""
	echo "description: \"Workspace kit for $workspace\""

	echo 'permissions:'
	echo '  network:'
	echo '    allow:'
	while IFS= read -r entry; do
		[ -n "$entry" ] || continue
		printf '      - "%s"\n' "$(yaml_escape "$entry")"
	done <<<"$domains"

	# GitHub, for `gh` and for git over HTTPS. The token is never copied into the
	# sandbox: `sbx secret set github` stores it on the host, the runtime injects
	# the Authorization header at the proxy, and GH_TOKEN inside the VM holds only
	# the sentinel. That is the whole replacement for the shared devbox-gh-auth
	# volume — one `sbx secret set`, no volume, no key to chown.
	#
	# Every domain injected into must also appear in the allow list above; all
	# five are in ../allowed-domains.
	cat <<-'YAML'
		credentials:
		  - service: github
		    description: "gh CLI and git over HTTPS"
		    apiKey:
		      name: GH_TOKEN
		      inject:
		        - domain: api.github.com
		          header: Authorization
		          format: Bearer %s
		        - domain: github.com
		          header: Authorization
		          format: Bearer %s
		        - domain: raw.githubusercontent.com
		          header: Authorization
		          format: Bearer %s
		        - domain: codeload.github.com
		          header: Authorization
		          format: Bearer %s
		        - domain: objects.githubusercontent.com
		          header: Authorization
		          format: Bearer %s
	YAML

	if [ -n "$environment" ]; then
		echo 'environment:'
		echo '  variables:'
		printf '%s\n' "$environment"
	fi

	# GitNexus writes its index to `<repo>/.gitnexus`, a path hardcoded in the
	# tool (storage/repo-manager.js `getStoragePath`); only the small global
	# registry moves, via GITNEXUS_HOME. A block volume over that one directory is
	# therefore the only way to keep a database, a WAL and a parse cache out of
	# the checkout — and out of the virtiofs bind mount, where a database file is
	# the worst possible workload.
	#
	# Sized rather than left to the block driver's 50 GiB default: an unsized
	# volume costs ~800 MiB of host space the moment it is mounted, because the
	# kernel zeroes ext4's inode tables.
	echo 'volumes:'
	printf '  - path: %s/.gitnexus\n    size: 4g\n    mode: "0755"\n' "$workspace"

	# The profile's own, from a `volumes` file: one `path [size]` per line, the
	# same three placeholders as `env`. This is the escape hatch the compose
	# fragments used to be — a hot directory inside the workspace that should not
	# live on the bind mount (node_modules, a build output) is the case it exists
	# for. Per sandbox and named deterministically by it, so a `devbox rebuild`
	# keeps them and only `devbox down` does not.
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[ -n "$line" ] || continue
		path="${line%%[[:space:]]*}"
		size="${line##*[[:space:]]}"
		[ "$size" = "$path" ] && size="4g"
		path="${path//%WORKSPACE%/$workspace}"
		path="${path//%TOOLS%/$tools}"
		path="${path//%CACHES%/$caches}"
		printf '  - path: %s\n    size: %s\n    mode: "0755"\n' "$path" "$size"
	done < <([ -f "$dir/volumes" ] && cat "$dir/volumes" || true)

	echo 'setup:'
	echo '  install:'
	setup_install
} >"$tmp/spec.yaml"

# --- The files the sandbox starts with ----------------------------------------
#
# Your user-level skills, agents and CLAUDE.md, copied out of your host config
# into files/home/, which sbx unpacks into /home/agent at create. This is the
# whole of what stage-host-config.sh + install-host-config.sh used to do across
# a read-only bind mount and a manifest-driven prune — the kit is rebuilt from
# scratch every time, so removing a skill on the host removes it here too.
mkdir -p "$tmp/files/home/.claude"
DEVBOX_CLAUDE_STAGE="$tmp/files/home/.claude" bash "$here/stage-claude-config.sh"

rm -rf "$out"
mv "$tmp" "$out"
trap - EXIT

# --- The profile's own host-side hook -----------------------------------------
#
# The counterpart of setup.sh, on this side of the VM: for whatever a profile
# needs to exist on the *host* before the sandbox starts — a companion stack it
# connects to over host.docker.internal, a directory a mount points at. See
# ../projects/rocketchat/initialize.sh.
#
# It must be idempotent and it must not be fatal for a reason outside the user's
# control: this runs on every create, and failing here means no sandbox at all.
if [ -f "$dir/initialize.sh" ]; then
	log "running the profile's initialize.sh"
	bash "$dir/initialize.sh"
fi

log "wrote $out/spec.yaml ($(printf '%s\n' "$domains" | grep -c . || true) allowed hosts, profile $profile)"
