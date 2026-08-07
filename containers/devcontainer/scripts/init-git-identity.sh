#!/usr/bin/env bash
#
# Runs on the HOST from initialize.sh (devcontainer.json's initializeCommand),
# before the container is created.
#
# Copies your git author identity into the container, so commits made in here are
# authored by you. Without it git finds no user.name/user.email in a fresh
# container and refuses to commit at all ("Please tell me who you are"), or worse
# guesses from the hostname once EMAIL is set in the environment.
#
# Read from the workspace root rather than with a bare `git config --global
# --get`, so the *effective* identity wins: a repo-local user.email (a work
# address on a work checkout) is what the host would commit with, and it is what
# should apply in here too. In a linked worktree the local config comes from the
# shared git dir, so every worktree agrees.
#
# The values travel as environment on the service — scripts/on-create.sh turns
# them into real `git config --global` entries in the container, rather than
# exporting GIT_AUTHOR_*/GIT_COMMITTER_* directly: those override even a
# repo-local identity set inside the container, and leave `git config user.email`
# answering nothing, which breaks anything that reads config instead of env.
#
# Note VS Code's Dev Containers extension already copies the host .gitconfig when
# dev.containers.copyGitConfig is on (the default). The `devcontainer` CLI does
# not, which is the gap this closes; both write ~/.gitconfig, so running under
# VS Code just sets the same two keys twice.
#
# Contributed as a compose fragment for the same reason as init-worktree.sh: the
# identity is only knowable on the host, and compose files are static.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${DEVBOX_WORKSPACE:-$PWD}"

source "$here/lib/overrides.sh"

log() { printf '\033[1;34m[git-identity]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[git-identity] WARNING:\033[0m %s\n' "$1" >&2; }

# No git on the host is not an error worth failing the create over — it just
# means there is nothing to copy. (There would still be a checkout here, since
# something had to produce it.)
if ! command -v git >/dev/null 2>&1; then
	warn "git not found on the host — skipping; set user.name/user.email in the container yourself"
	exit 0
fi

# `|| true` because --get exits 1 when the key is unset, which is a normal
# outcome here and must not trip set -e.
name="$(git -C "$root" config --get user.name 2>/dev/null || true)"
email="$(git -C "$root" config --get user.email 2>/dev/null || true)"

if [ -z "$name" ] && [ -z "$email" ]; then
	warn "no git user.name/user.email configured on the host — skipping; commits in the container will need an identity"
	exit 0
fi

# The `service-environment` bucket, not `service`: YAML has no merge, so
# `environment:` is opened once by lib/overrides.sh and every contributor —
# this one and the profile — just adds lines under it.
{
	[ -n "$name" ] && echo "DEVBOX_GIT_USER_NAME: \"$(overrides_yaml_escape "$name")\""
	[ -n "$email" ] && echo "DEVBOX_GIT_USER_EMAIL: \"$(overrides_yaml_escape "$email")\""
	true
} | overrides_add git-identity service-environment

log "copying git identity to the container: ${name:-<unset>} <${email:-unset}>"
