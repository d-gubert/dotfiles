#!/usr/bin/env bash
#
# Runs on the HOST from initialize.sh (devcontainer.json's initializeCommand),
# before the container is created.
#
# Turbo's cache: one host directory, bind-mounted into every container at the
# path TURBO_CACHE_DIR names (devcontainer.json).
#
#   ~/.cache/devbox/turbo  ->  /home/vscode/.turbo-cache
#
# Shared rather than per-workspace for the same reason as the yarn cache: every
# workspace is its own compose project, so a per-workspace cache means every
# worktree of the same repo rebuilds what its sibling already built. Turbo's
# hashes are content-based, so two worktrees on the same commit hash a task
# identically and the second one gets a hit.
#
# A host directory and not a named volume, which is what
# ensure-yarn-cache.sh uses for the same job:
#
#   - A build on the host (`turbo run build` outside any container) shares it by
#     exporting TURBO_CACHE_DIR to this path. That is the one thing the remote
#     cache server offered — it published 127.0.0.1:3399 — and the only reason
#     not to use a volume here.
#   - remoteUser is vscode, whose uid the devcontainer CLI matches to the host
#     user's, so a directory this script creates is already writable in the
#     container. A named volume's mount point lands root-owned and needs the
#     throwaway busybox chown the other ensure-* scripts do.
#   - `du -sh` and `rm -rf` work on it without a container.
#
# It replaces the Turborepo remote cache server, which is still in
# ../turbo-cache/docker-compose.yml but wired to nothing — see that file's header
# for what it cost and how to put it back.
#
# Idempotent: this runs on every create and rebuild in every workspace.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/overrides.sh"

# XDG_CACHE_HOME because that is what the path means — a cache, safe to delete,
# and something a "clear my caches" tool is allowed to take.
host_dir="${XDG_CACHE_HOME:-$HOME/.cache}/devbox/turbo"

log() { printf '\033[1;34m[turbo-cache]\033[0m %s\n' "$1"; }

if [ ! -d "$host_dir" ]; then
	mkdir -p "$host_dir"
	log "created $host_dir — shared by every workspace, delete it to clear the cache"
fi

# The mount is contributed rather than checked into docker-compose.yml because
# its source is a host path, which no compose file in a dotfiles repo can name.
# Same reason the /opt/devbox mount is contributed from initialize.sh.
overrides_add turbo-cache service-volumes <<-YAML
	- type: bind
	  source: $host_dir
	  target: /home/vscode/.turbo-cache
YAML
