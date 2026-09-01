#!/usr/bin/env bash
#
# Runs on the HOST from build-kit.sh, before the sandbox is created.
#
# Prints your git author identity as KEY=VALUE lines on stdout, for build-kit.sh
# to fold into the kit's environment. Prints nothing when the host has no
# identity configured — everything else here is a warning on stderr.
#
# Without it git finds no user.name/user.email in a fresh sandbox and refuses to
# commit at all ("Please tell me who you are"), or worse guesses from the
# hostname once EMAIL is set in the environment.
#
# Read from the workspace root rather than with a bare `git config --global
# --get`, so the *effective* identity wins: a repo-local user.email (a work
# address on a work checkout) is what the host would commit with, and it is what
# should apply in here too. In a linked worktree the local config comes from the
# shared git dir, so every worktree agrees.
#
# The values travel as DEVBOX_GIT_USER_* rather than GIT_AUTHOR_*/GIT_COMMITTER_*,
# and the kit's setup.install turns them into real `git config --global` entries
# in the sandbox. The GIT_* pair would override even a repo-local identity set
# inside the sandbox, and would leave `git config user.email` answering nothing,
# which breaks anything that reads config instead of the environment.
set -euo pipefail

root="${DEVBOX_WORKSPACE:-$PWD}"

warn() { printf '\033[1;33m[git-identity] WARNING:\033[0m %s\n' "$1" >&2; }

# No git on the host is not an error worth failing the create over — it just
# means there is nothing to copy. (There would still be a checkout here, since
# something had to produce it.)
if ! command -v git >/dev/null 2>&1; then
	warn "git not found on the host — skipping; set user.name/user.email in the sandbox yourself"
	exit 0
fi

# `|| true` because --get exits 1 when the key is unset, which is a normal
# outcome here and must not trip set -e.
name="$(git -C "$root" config --get user.name 2>/dev/null || true)"
email="$(git -C "$root" config --get user.email 2>/dev/null || true)"

if [ -z "$name" ] && [ -z "$email" ]; then
	warn "no git user.name/user.email configured on the host — commits in the sandbox will need an identity"
	exit 0
fi

[ -n "$name" ] && printf 'DEVBOX_GIT_USER_NAME=%s\n' "$name"
[ -n "$email" ] && printf 'DEVBOX_GIT_USER_EMAIL=%s\n' "$email"
true
