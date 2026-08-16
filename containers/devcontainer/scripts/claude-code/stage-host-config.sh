#!/usr/bin/env bash
#
# Runs on the HOST from claude-code/initialize.sh, before the container is
# created or started.
#
# Copies the parts of your user-level Claude Code config that the container
# should share — your skills and your CLAUDE.md — into $DEVBOX_STATE/host-config,
# which claude-code/initialize.sh binds read-only at /opt/devbox-host-config,
# where install-host-config.sh puts them in place:
#
#     host-config/
#       skills/<name>/...
#       CLAUDE.md
#
# Two halves are needed because the container's ~/.claude is a named volume —
# nothing on the host is visible inside it.
#
# Why copy instead of binding your config directory straight in: both halves are
# commonly symlinks into another checkout (a skill at ~/.agents/skills/<name>, a
# CLAUDE.md in a dotfiles repo), and those targets are not mounted into the
# container, so the links would resolve to nothing in there. `cp -RL` and `cp -L`
# here dereference them while the targets still exist.
#
# It lands in the per-workspace state directory rather than in the dotfiles: that
# directory is mounted read-only in the container, and several workspaces can be
# starting at once.
#
# Source honours $CLAUDE_CONFIG_DIR, falling back to ~/.claude — the same
# resolution Claude Code itself uses. So `CLAUDE_CONFIG_DIR=~/.claude-personal
# devbox up` stages that profile's config instead.
#
# Idempotent: re-runs on every create/start and fully rebuilds the staging
# directory, so removing a skill or the CLAUDE.md on the host removes it in the
# container too.
#
# To opt out entirely, see the marker file / env var below.
set -euo pipefail

src="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
out="${DEVBOX_STATE:?}/host-config"
optout="$DEVBOX_STATE/skip-host-config"

log() { printf '\033[1;34m[stage-host-config]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[stage-host-config] WARNING:\033[0m %s\n' "$1" >&2; }

# An empty staging directory is not the same as no staging directory: the
# container side reads staging as authoritative, so this is what tells it to
# remove what it installed on an earlier run. (It also has to exist either way —
# a bind mount whose source is missing gets created as a root-owned directory by
# Docker.) skills/ is always created for the same reason.
stage_empty() {
	rm -rf "$out"
	mkdir -p "$out/skills"
}

# Opting out. The marker file is the dependable one: initializeCommand inherits
# the environment of whatever launched the editor, which for a GUI launch is
# usually not your shell — so an exported variable may simply not be there. The
# variable is for scripted use of `devbox`.
if [ -f "$optout" ]; then
	log "opted out by $optout — not copying host config"
	stage_empty
	exit 0
fi
if [ "${DEVBOX_SKIP_HOST_CONFIG:-0}" != "0" ]; then
	log "opted out by DEVBOX_SKIP_HOST_CONFIG — not copying host config"
	stage_empty
	exit 0
fi

if [ ! -d "$src" ]; then
	log "no config directory at $src — nothing to stage"
	stage_empty
	exit 0
fi

# Build beside the target and swap, so an interrupted run can't leave the
# container reading a half-copied skill.
tmp="$out.tmp.$$"
rm -rf "$tmp"
mkdir -p "$tmp/skills"
trap 'rm -rf "$tmp"' EXIT

count=0
shopt -s nullglob
for entry in "$src"/skills/*; do
	name="$(basename "$entry")"
	# False for a symlink whose target is gone — worth saying out loud, since the
	# skill works on the host only for as long as the target exists.
	if [ ! -e "$entry" ]; then
		warn "skipping skill '$name' — broken symlink"
		continue
	fi
	# A skill is a directory (SKILL.md plus its references). Anything else in
	# here is not one.
	[ -d "$entry" ] || continue
	cp -RL "$entry" "$tmp/skills/$name"
	count=$((count + 1))
done
shopt -u nullglob

# The user-level memory file, next to skills/ and under the same rules. `-e` is
# false for a dangling symlink too, so both cases land in the else branch.
memory="no CLAUDE.md"
if [ -e "$src/CLAUDE.md" ]; then
	cp -L "$src/CLAUDE.md" "$tmp/CLAUDE.md"
	memory="CLAUDE.md"
elif [ -L "$src/CLAUDE.md" ]; then
	warn "skipping CLAUDE.md — broken symlink"
fi

rm -rf "$out"
mv "$tmp" "$out"
trap - EXIT

log "staged $count skill(s) and $memory from $src"
