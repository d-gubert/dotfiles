#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from devcontainer.json's onCreateCommand, once per
# container create/rebuild.
#
# This is onCreate rather than postCreate because updateContentCommand runs
# *between* the two, and it needs the volumes below to already be writable.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/features.sh"

log() { printf '\033[1;34m[on-create]\033[0m %s\n' "$1"; }

# A note that applies to every claim below, and to the per-feature ones in
# scripts/<name>/on-create.sh: named volumes mount as root:root, so whatever runs
# as `vscode` and writes under them gets EACCES until they are claimed.
#
# Keep them targeted rather than chowning all of /home/vscode: a recursive chown
# there would walk into any bind mount that lands under it and rewrite ownership
# of the host's files. Note also that Docker creates any *missing parent* of a
# mount target as root before the container runs, so a volume nested under a path
# that is not in the base image needs its parents claimed here too.
#
# ~/.yarn is exactly that missing-parent case: nothing in the base image creates
# it, so Docker makes it as root before mounting the shared yarn cache at
# ~/.yarn/berry. yarn writes install-state and its own files alongside berry/, so
# the parent has to be ours too. Not recursive — the volume itself arrives owned
# by the right uid (ensure-yarn-cache.sh) and holds a warm cache of tens of
# thousands of files.
log "claiming ~/.yarn"
sudo chown vscode:vscode /home/vscode/.yarn /home/vscode/.yarn/berry

# The profile's durable scratch (scripts/init-profile.sh). Already owned by the
# right uid from the host side; this is the belt-and-braces pass, and it is what
# claims the mount point when the volume was created some other way.
log "claiming $DEVBOX_TOOLS"
sudo chown vscode:vscode "$DEVBOX_TOOLS"

# Your git author identity, read off the host by scripts/init-git-identity.sh and
# passed in as environment on the service. Written as real config rather than left
# in the environment so `git config user.email` answers, and so a repo-local
# identity set inside the container still wins — see that script for why.
#
# Safe to write unconditionally: the container's home is not a volume, so this
# runs against a fresh ~/.gitconfig on every create. Under VS Code that file may
# already be a copy of the host's (dev.containers.copyGitConfig), in which case
# this sets the same two keys to the same values.
if [ -n "${DEVBOX_GIT_USER_NAME:-}" ]; then
	log "setting git user.name to $DEVBOX_GIT_USER_NAME"
	git config --global user.name "$DEVBOX_GIT_USER_NAME"
fi
if [ -n "${DEVBOX_GIT_USER_EMAIL:-}" ]; then
	log "setting git user.email to $DEVBOX_GIT_USER_EMAIL"
	git config --global user.email "$DEVBOX_GIT_USER_EMAIL"
fi

# A safety belt for the worktree setup: the container can see the shared git
# dir but not the *other* worktrees' host paths, so from in here they all look
# like they "point to a non-existent location" and become prune candidates
# once past gc.worktreePruneExpire (default 3 months). A routine `git gc`
# inside the container would then unregister worktrees that are perfectly
# healthy on the host — verified: it really does list all of them as
# removable.
#
# This covers `git gc`/`gc --auto`, which pass this value through as --expire.
# It does NOT cover an explicit `git worktree prune`: that defaults to
# expiring everything and ignores the config. Don't run it in here.
log "disabling worktree pruning during gc"
git config --global gc.worktreePruneExpire never

# Per-feature create-time setup: scripts/<name>/on-create.sh for every feature
# devcontainer.json actually declares. Mostly claiming the mount points of the
# volumes those features contributed on the host side.
run_feature_hooks on-create.sh
