#!/usr/bin/env bash
#
# Runs on the HOST from `devbox`, before the sandbox is created.
#
# Prints the extra host paths this checkout needs mounted, one per line, for
# `devbox` to pass to `sbx create` as additional workspaces. Prints nothing for
# an ordinary checkout.
#
# Why it exists: in a linked git worktree, `.git` is not a directory but a file
# containing an absolute host path, e.g.
#
#     gitdir: /home/you/dev/SomeRepo/.git/worktrees/my-branch
#
# The workspace mount carries that file into the sandbox verbatim, but the path
# it names is not there — so every git command inside fails with "not a git
# repository". Mounting the real git dir fixes it, and fixes it with no rewriting
# of git metadata and nothing copied, because sbx mounts every workspace at the
# same absolute path it has on the host: the `gitdir:` pointer, and the
# `commondir` relative link beside it, resolve unchanged.
#
# One mount, read-write, where the devcontainer needed four. Same-path mounting
# removes two of them (the workspace's own .git file and the back-pointer come
# with the workspace itself), and the read-only mount over `worktrees/` is gone
# with them: it existed so that no git command in the container could unregister
# a *sibling* worktree, and the kit's `gc.worktreePruneExpire never` (build-kit.sh)
# is what covers that now. It covers `git gc`, not an explicit
# `git worktree prune` — don't run that in a sandbox.
set -euo pipefail

root="${DEVBOX_WORKSPACE:-$PWD}"

command -v git >/dev/null 2>&1 || exit 0

# --git-common-dir is the shared git dir: the worktree's own .git in a normal
# checkout, the *main* repo's .git when called from a linked worktree.
common="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"

# Not a git repo at all, or the primary worktree (its git dir sits inside the
# workspace, so the workspace mount already covers it) — nothing to add.
if [ -z "$common" ] || [ "$common" = "$root/.git" ]; then
	exit 0
fi

# A trailing slash would produce a doubled separator in the mount spec.
printf '%s\n' "${common%/}"
