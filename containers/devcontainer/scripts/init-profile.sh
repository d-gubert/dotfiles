#!/usr/bin/env bash
#
# Runs on the HOST from initialize.sh (devcontainer.json's initializeCommand),
# before the container is created.
#
# Applies the host-side half of the workspace's profile — see lib/profile.sh for
# what a profile is and how one is picked. Everything here is optional: a profile
# with nothing but a `match` file contributes nothing and you get the bare
# toolchain container.
#
#   env, env.local     -> services.app.environment
#   ports              -> services.app.ports
#   compose/*.yml      -> the matching override bucket, verbatim
#   (always)           -> the shared devbox-tools-<profile> volume at $DEVBOX_TOOLS
#
# The container-side half is projects/<name>/setup.sh, run from
# update-content.sh, and projects/<name>/allowed-domains, read by the firewall.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/overrides.sh"
source "$here/lib/profile.sh"

profile="${DEVBOX_PROFILE:?}"
dir="$(profile_dir "$profile")"

log() { printf '\033[1;34m[profile:%s]\033[0m %s\n' "$profile" "$1"; }
warn() { printf '\033[1;33m[profile:%s] WARNING:\033[0m %s\n' "$profile" "$1" >&2; }

if [ ! -d "$dir" ]; then
	warn "no such profile at $dir — continuing with the bare toolchain container"
	exit 0
fi

# --- Durable scratch for the toolchains a profile installs --------------------
#
# A profile's setup.sh installs what its repo needs (a Meteor warehouse, a Deno
# version, an SDK) and needs somewhere to put it that outlives the container: the
# home directory is part of the writable layer and a rebuild takes it with it,
# and the workspace is somebody else's repo.
#
# One volume per profile, shared by every workspace on it — so all your worktrees
# of the same repo download that toolchain once between them. External with a
# fixed name for exactly that reason: an ordinary volume would be namespaced per
# compose project, i.e. per workspace. See ensure-yarn-cache.sh for the longer
# version of the same argument.
tools_volume="devbox-tools-$profile"
if ! docker volume inspect "$tools_volume" >/dev/null 2>&1; then
	docker volume create "$tools_volume" >/dev/null
	# Compose has no chown and a named volume's mount point lands root-owned, so a
	# throwaway busybox claims it for the container user (remoteUser vscode, whose
	# uid devcontainers matches to the host user's).
	docker run --rm -v "$tools_volume":/v busybox:1.37 \
		sh -c "chown -R $(id -u):$(id -u) /v"
	log "created $tools_volume — profile toolchains persist across rebuilds"
fi

overrides_add profile service-volumes <<-YAML
	- type: volume
	  source: devbox-tools
	  target: /home/vscode/.devbox
YAML

overrides_add profile volumes <<-YAML
	devbox-tools:
	  external: true
	  name: $tools_volume
YAML

# --- Environment --------------------------------------------------------------
#
# KEY=VALUE lines, with an optional gitignored env.local layered on top for
# anything secret — a license key, a token — that has no business in a dotfiles
# repo. Later wins, so env.local can also override a value from env.
#
# One fragment for both files, and a separate `service-environment` bucket, so
# `environment:` is opened exactly once under services.app no matter how many
# contributors want to add to it (git identity is the other one).
emit_env_file() {
	local file="$1" line key value
	[ -f "$file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		# Comments only on their own line: a `#` inside a value is a legitimate
		# character (URLs, passwords) and stripping it would corrupt the value.
		case "$line" in '' | '#'*) continue ;; esac
		[ "$line" != "${line#*=}" ] || {
			warn "ignoring line without '=' in $(basename "$file"): $line"
			continue
		}
		key="${line%%=*}"
		value="${line#*=}"
		key="${key#"${key%%[![:space:]]*}"}"
		key="${key%"${key##*[![:space:]]}"}"
		key="${key#export }"
		# Strip one layer of matching quotes, the way an .env file is usually
		# written; the value is re-quoted for YAML below either way.
		case "$value" in
		\'*\') value="${value#\'}" value="${value%\'}" ;;
		\"*\") value="${value#\"}" value="${value%\"}" ;;
		esac
		printf '%s: "%s"\n' "$key" "$(overrides_yaml_escape "$value")"
	done <"$file"
}

{
	emit_env_file "$dir/env"
	emit_env_file "$dir/env.local"
} | {
	# Only open the fragment when there is something in it — an empty
	# `environment:` block is valid but noise.
	body="$(cat)"
	[ -n "$body" ] && printf '%s\n' "$body" | overrides_add profile-env service-environment
	true
}

# --- Published ports ----------------------------------------------------------
#
# `host:container` per line. DEVBOX_PORTS (comma or space separated) overrides
# the file, which is how you run a second workspace of the same profile without
# both of them fighting over the host port.
ports_from_file() {
	[ -f "$dir/ports" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%%#*}"
		line="${line//[[:space:]]/}"
		[ -n "$line" ] && printf '%s\n' "$line"
	done <"$dir/ports"
}

if [ -n "${DEVBOX_PORTS:-}" ]; then
	ports="$(printf '%s' "$DEVBOX_PORTS" | tr ', ' '\n\n' | grep -v '^$' || true)"
else
	ports="$(ports_from_file)"
fi

if [ -n "$ports" ]; then
	{
		echo "ports:"
		while IFS= read -r port; do
			[ -n "$port" ] || continue
			printf '  - "%s"\n' "$port"
		done <<<"$ports"
	} | overrides_add profile-ports service
	log "publishing ports: $(printf '%s ' $ports)"
fi

# --- Raw compose fragments ----------------------------------------------------
#
# The escape hatch for anything the files above cannot express — an extra service,
# a named volume over a hot directory in the bind mount, a sysctl. One file per
# bucket, copied in with three placeholders substituted; see lib/overrides.sh for
# what each bucket is.
#
# The placeholders exist because a mount target inside the workspace has to name
# the container's workspace path, which is per-workspace and therefore unknown to
# any checked-in file. Substitution rather than shell expansion: a compose
# fragment is data, and `eval`-ing it would make a profile a second place where
# arbitrary host commands run.
#
#   %WORKSPACE%  the workspace path inside the container
#   %TOOLS%      the profile's durable scratch volume (= $DEVBOX_TOOLS)
#   %PROFILE%    this profile's name
for bucket in service service-environment service-volumes volumes; do
	fragment="$dir/compose/$bucket.yml"
	[ -f "$fragment" ] || continue
	sed -e "s|%WORKSPACE%|${DEVBOX_CONTAINER_WORKSPACE:?}|g" \
		-e "s|%TOOLS%|/home/vscode/.devbox|g" \
		-e "s|%PROFILE%|$profile|g" \
		"$fragment" |
		overrides_add "profile-compose-$bucket" "$bucket"
	log "added compose/$bucket.yml"
done
