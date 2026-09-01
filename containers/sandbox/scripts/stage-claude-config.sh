#!/usr/bin/env bash
#
# Runs on the HOST from build-kit.sh, before the sandbox is created.
#
# Copies the parts of your user-level Claude Code config that the sandbox should
# share — your skills, your agents and your CLAUDE.md — into the kit's files/home
# tree, which sbx unpacks into /home/agent at create:
#
#     $DEVBOX_CLAUDE_STAGE/       (= <kit>/files/home/.claude)
#       skills/<name>/...
#       agents/<name>.md
#       CLAUDE.md
#
# Why copy instead of mounting your config directory: all three parts are
# commonly symlinks into another checkout (a skill at ~/.agents/skills/<name>, an
# agent or a CLAUDE.md in a dotfiles repo), and those targets are not mounted
# into the sandbox, so the links would resolve to nothing in there. `cp -RL` and
# `cp -L` here dereference them while the targets still exist.
#
# It lands in the per-workspace state directory rather than in the dotfiles:
# several workspaces can be starting at once, and the kit is rebuilt from scratch
# on every `up` — which is what makes a skill removed on the host disappear from
# the sandbox, with no manifest and no prune pass.
#
# Nothing here writes towards ~/.claude/projects, ~/.claude/sessions or
# .credentials.json. Those are the built-in `claude` kit's business: it mounts a
# volume over each, keyed by sandbox name, so a session survives a recreate and
# the OAuth token never lands in a file at all.
#
# Source honours $CLAUDE_CONFIG_DIR, falling back to ~/.claude — the same
# resolution Claude Code itself uses. So `CLAUDE_CONFIG_DIR=~/.claude-personal
# devbox up` stages that profile's config instead.
#
# To opt out entirely, see the marker file / env var below.
set -euo pipefail

src="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
out="${DEVBOX_CLAUDE_STAGE:?}"
optout="${DEVBOX_STATE:?}/skip-host-config"

log() { printf '\033[1;34m[claude-config]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[claude-config] WARNING:\033[0m %s\n' "$1" >&2; }

# skills/ and agents/ are created whether or not anything lands in them: an
# `sbx exec` that installs a skill by hand should find the directory there.
mkdir -p "$out/skills" "$out/agents"

# Opting out. The marker file is the dependable one: `devbox` may be run from an
# editor or a launcher whose environment is not your shell's, so an exported
# variable may simply not be there. The variable is for scripted use.
if [ -f "$optout" ]; then
	log "opted out by $optout — not copying host config"
	exit 0
fi
if [ "${DEVBOX_SKIP_HOST_CONFIG:-0}" != "0" ]; then
	log "opted out by DEVBOX_SKIP_HOST_CONFIG — not copying host config"
	exit 0
fi

if [ ! -d "$src" ]; then
	log "no config directory at $src — nothing to stage"
	exit 0
fi

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
	cp -RL "$entry" "$out/skills/$name"
	count=$((count + 1))
done
shopt -u nullglob

# Subagent definitions, under the same rules as the skills above. An agent is one
# Markdown file, but Claude Code also reads the subdirectories some people group
# them in, so anything that survives the broken-symlink check is copied as it is.
agents=0
shopt -s nullglob
for entry in "$src"/agents/*; do
	name="$(basename "$entry")"
	if [ ! -e "$entry" ]; then
		warn "skipping agent '$name' — broken symlink"
		continue
	fi
	cp -RL "$entry" "$out/agents/$name"
	agents=$((agents + 1))
done
shopt -u nullglob

# The user-level memory file, next to skills/ and under the same rules. `-e` is
# false for a dangling symlink too, so both cases land in the else branch.
#
# It does NOT overwrite the profile file the `claude` kit owns: that one is
# CLAUDE.md in the workspace, and this is ~/.claude/CLAUDE.md.
memory="no CLAUDE.md"
if [ -e "$src/CLAUDE.md" ]; then
	cp -L "$src/CLAUDE.md" "$out/CLAUDE.md"
	memory="CLAUDE.md"
elif [ -L "$src/CLAUDE.md" ]; then
	warn "skipping CLAUDE.md — broken symlink"
fi

# The kit is packed and unpacked as the agent user, and a copy inherits the mode
# bits of whatever it came from — a read-only source directory would arrive
# unwritable, so a skill could not be edited in the sandbox.
chmod -R u+w "$out"

log "staged $count skill(s), $agents agent(s) and $memory from $src"
