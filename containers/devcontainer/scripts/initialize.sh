#!/usr/bin/env bash
#
# Runs on the HOST from devcontainer.json's initializeCommand, before the
# container is created.
#
# Everything here is a prerequisite of container *create*, not setup that could
# be deferred to a later lifecycle hook — see each script's header for what
# breaks without it. Two recurring reasons: compose refuses to create the
# container when an external volume is missing, and it is the only hook that runs
# on the host, so files it stages exist nowhere the container can reach until it
# does.
#
# It is also where the per-workspace docker-compose.overrides.yml is assembled.
# Contributors below stage fragments (lib/overrides.sh) and the merge happens
# once at the end, so the generated file is written in one shot rather than grown
# in place.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/features.sh"
source "$here/lib/overrides.sh"
source "$here/lib/profile.sh"

log() { printf '\033[1;34m[devbox]\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m[devbox] ERROR:\033[0m %s\n' "$1" >&2; exit 1; }

# This config only makes sense with the variables `devbox` derives from your
# pwd — devcontainer.json is built entirely out of them. Rather than let the CLI
# substitute empty strings and fail three steps later with a compose error about
# a path at the filesystem root, say what is actually wrong.
[ -n "${DEVBOX_STATE:-}" ] || die "DEVBOX_STATE is unset — start this container with \`devbox up\`, not the devcontainer CLI directly"

# The host directory this script lives in; the container sees the same directory,
# read-only, at /opt/devbox.
DEVBOX_HOME="$(cd "$here/.." && pwd)"
# initializeCommand runs with the workspace folder as its cwd, which is the
# fallback if the wrapper did not say.
DEVBOX_WORKSPACE="${DEVBOX_WORKSPACE:-$PWD}"
DEVBOX_PROFILE="${DEVBOX_PROFILE:-$(profile_resolve "$DEVBOX_WORKSPACE")}"
# Where lib/overrides.sh writes, and the same path devcontainer.json's
# `dockerComposeFile` includes.
DEVBOX_OVERRIDES_OUT="$DEVBOX_STATE/docker-compose.overrides.yml"
# The same path devcontainer.json's `workspaceFolder` resolves to. Contributors
# need it for anything whose mount target sits inside the workspace, which no
# checked-in compose file can name — see init-profile.sh's placeholders.
DEVBOX_CONTAINER_WORKSPACE="/workspaces/${DEVBOX_WORKSPACE_SLUG:?}"
export DEVBOX_HOME DEVBOX_WORKSPACE DEVBOX_PROFILE DEVBOX_STATE DEVBOX_OVERRIDES_OUT
export DEVBOX_CONTAINER_WORKSPACE

log "workspace $DEVBOX_WORKSPACE (profile: $DEVBOX_PROFILE)"

# Fragments are staged in a temp directory, not in the state directory: only the
# merged result belongs there. Cleared on any exit, including a failure partway
# through — a half-collected staging directory must never be merged on the next
# run.
overrides_reset
trap overrides_cleanup EXIT

# This directory, where the container's half of it lives. Contributed as a
# compose fragment rather than declared in devcontainer.json's `mounts`, because
# the CLI folds those into a compose override in the SHORT `source:target` form
# and silently drops the options — a `readonly` there does nothing, which is easy
# to miss and is the whole point of this mount. Verify with
# `devbox exec touch /opt/devbox/x`, which must fail.
{
	echo "- type: bind"
	echo "  source: $DEVBOX_HOME"
	echo "  target: /opt/devbox"
	echo "  read_only: true"
} | overrides_add devbox service-volumes

# GitNexus writes its index to `<repo>/.gitnexus`, a path hardcoded in the tool
# (storage/repo-manager.js `getStoragePath`); only the small global registry
# moves, via GITNEXUS_HOME. A named volume over that one directory is therefore
# the only way to keep a database, a WAL and a parse cache out of the checkout —
# the same trick the rocketchat profile uses for node_modules.
#
# Ordinary (non-external) volume on purpose: compose namespaces it per project,
# i.e. per workspace, and an index describes exactly one checkout.
#
# The checkout does still get a `.gitnexus` directory on the host, because Docker
# creates a missing mount target before the container runs — but the volume
# shadows it, so it stays *empty* and root-owned over there. Git does not report
# empty directories, so `git status` is unaffected; removing it by hand needs
# sudo. on-create.sh claims the volume's own root, which is a different inode.
{
	echo "- type: volume"
	echo "  source: gitnexus-index"
	echo "  target: ${DEVBOX_CONTAINER_WORKSPACE}/.gitnexus"
} | overrides_add gitnexus service-volumes
echo "gitnexus-index: {}" | overrides_add gitnexus volumes

# Contributes the git-dir mounts when this checkout is a linked worktree, and
# nothing at all when it is not.
bash "$here/init-worktree.sh"

# Passes your host git author identity through to the container, where
# on-create.sh writes it into the container's global git config. Nothing to
# contribute when the host has no identity configured.
bash "$here/init-git-identity.sh"

# Everything the matched profile contributes: its environment, its published
# ports, its shared tools volume, any raw compose fragments. Nothing at all for a
# profile that is just a `match` file.
bash "$here/init-profile.sh"

# Creates the host directory that holds turbo's cache and contributes the bind
# mount for it. Host-side because the source is a host path, pre-create because
# a profile's setup.sh (updateContentCommand) is usually the first thing to build.
bash "$here/ensure-turbo-cache-dir.sh"

# Creates the shared Yarn cache volume (~/.yarn/berry: the package zips and
# metadata index) — external volume, mounted through a subpath that has to exist
# before the container starts.
#
# Not feature-gated: the JS toolchain is what this image is, not an opt-in.
bash "$here/ensure-yarn-cache.sh"

# Per-feature host-side setup: scripts/<name>/initialize.sh for every feature
# devcontainer.json actually declares. Each contributes its own compose fragment,
# so a feature that is commented out leaves no volume to create and no mount
# pointing at one.
run_feature_hooks initialize.sh

# Everything staged above, merged into the single generated compose file that
# devcontainer.json includes.
overrides_write
