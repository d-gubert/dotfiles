#!/usr/bin/env bash
# Rename the focused tab after the repo (and branch) of the focused pane.
#
# Ported from `bind w run-shell` in ../../../.tmux.conf, bound to prefix+w in
# ../config.toml. Result looks like "d-gubert/dotfiles#main", falling back to
# the directory basename when the pane isn't in a GitHub repo.
#
# herdr runs keys.command entries detached, without the HERDR_* env vars a pane
# shell gets, so the pane is resolved over the socket API instead of from $PWD.
set -eu

pane=$(herdr pane current)
cwd=$(jq -r '.result.pane.foreground_cwd // .result.pane.cwd' <<<"$pane")
workspace=$(jq -r '.result.pane.workspace_id' <<<"$pane")

[ -n "$cwd" ] && [ "$cwd" != "null" ] || exit 1
[ -n "$workspace" ] && [ "$workspace" != "null" ] || exit 1

cd "$cwd"

repo=$(gh repo view --json nameWithOwner -q ".nameWithOwner" 2>/dev/null || true)

if [ -n "$repo" ]; then
	label=$repo
else
	label=$(basename "$cwd")
fi

# Branch name, or the short sha when detached — same two cases the tmux version
# picked out of `git status --branch`.
if ref=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
	label="$label#$ref"
elif ref=$(git rev-parse --short HEAD 2>/dev/null); then
	label="$label#$ref"
fi

herdr workspace rename "$workspace" "$label"
