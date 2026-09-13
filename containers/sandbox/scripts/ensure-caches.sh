#!/usr/bin/env bash
#
# Runs on the HOST from `devbox`, before the sandbox is created.
#
# Creates the directories every workspace shares, and prints them one per line
# for `devbox` to pass to `sbx create` as additional workspaces:
#
#   $DEVBOX_CACHES/yarn-berry      Yarn's global folder — the package zips and
#                                  its metadata index (YARN_GLOBAL_FOLDER)
#   $DEVBOX_CACHES/turbo           Turborepo's cache (TURBO_CACHE_DIR)
#   $DEVBOX_CACHES/ms-playwright   Playwright's browser downloads
#                                  (PLAYWRIGHT_BROWSERS_PATH)
#   $DEVBOX_TOOLS                  durable scratch for the toolchains a profile
#                                  installs — one per profile, not per workspace
#
# build-kit.sh points each toolchain at its directory by exactly these paths,
# which works because sbx mounts a workspace at the same absolute path it has on
# the host: `~/.cache/devbox/turbo` is that same string inside the VM.
#
# Host directories, where the devcontainer used four named Docker volumes. Three
# reasons, in order of weight:
#
#   - A kit volume is block or tmpfs storage *inside* the VM. There is no kit
#     field for a host bind mount, and no `sbx` flag for one either: an extra
#     workspace argument is the only way in. See the kit spec, §5.7.
#   - A volume is per-sandbox. The whole point of these four is that every
#     workspace on the machine shares them — one download, not one per checkout.
#   - The host user is uid 1000 and so is the sandbox's `agent`, so a directory
#     created here is already writable in there. That deletes the chown-through-
#     a-throwaway-busybox dance each of the old ensure-*.sh scripts needed,
#     because a named volume's mount point lands root-owned and compose has no
#     chown.
#
# `du -sh` and `rm -rf` work on them without a sandbox, which is what "delete it
# to clear the cache" now means.
#
# Idempotent: this runs on every create in every workspace.
set -euo pipefail

caches="${DEVBOX_CACHES:?}"
tools="${DEVBOX_TOOLS:?}"

log() { printf '\033[1;34m[caches]\033[0m %s\n' "$1" >&2; }

for dir in "$caches/yarn-berry" "$caches/turbo" "$caches/ms-playwright" "$tools"; do
	if [ ! -d "$dir" ]; then
		mkdir -p "$dir"
		log "created $dir"
	fi
	printf '%s\n' "$dir"
done
