#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from claude-code/post-start.sh, on every start.
#
# Installs the skills that stage-skills.sh copied out of your host config and
# claude-code/initialize.sh bind-mounted read-only at /opt/devbox-skills, into
# the container's Claude Code config directory. Honours $CLAUDE_CONFIG_DIR and
# falls back to ~/.claude, matching the CLI's own resolution.
#
# Copied rather than symlinked so the skills survive the mount going away, and
# because the mount is read-only anyway — nothing in here can write back towards
# your host config.
#
# Runs on every start, not just onCreate, so editing a skill on the host only
# needs a container restart.
set -euo pipefail

staged="/opt/devbox-skills"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dest="$config_dir/skills"
# What the previous run installed. Used to prune skills that have since been
# removed on the host, without touching skills written directly in the
# container — those were never in here.
manifest="$config_dir/.host-skills.manifest"

log() { printf '\033[1;34m[install-skills]\033[0m %s\n' "$1"; }

if [ ! -d "$staged" ]; then
	# The mount is contributed by the same feature as this script, so its absence
	# means the container was brought up some other way (a plain
	# `docker compose up`). Leave whatever is installed alone.
	#
	# An *empty* staging directory is a different signal: the host deliberately
	# contributed nothing (no skills, or the sync is opted out), and the prune
	# below removes what an earlier run installed.
	log "nothing staged at $staged — skipping"
	exit 0
fi

mkdir -p "$dest"

if [ -f "$manifest" ]; then
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		[ -d "$staged/$name" ] && continue
		[ -d "$dest/$name" ] || continue
		log "removing '$name' — no longer on the host"
		rm -rf "$dest/$name"
	done <"$manifest"
fi

count=0
: >"$manifest"
shopt -s nullglob
for entry in "$staged"/*; do
	[ -d "$entry" ] || continue
	name="$(basename "$entry")"
	# Replace rather than merge, so a file deleted from a skill on the host does
	# not survive in the container copy.
	rm -rf "$dest/$name"
	cp -R "$entry" "$dest/$name"
	# The copy inherits the read-only mount's mode bits for directories; make our
	# own copy writable so a later run can replace it.
	chmod -R u+w "$dest/$name"
	printf '%s\n' "$name" >>"$manifest"
	count=$((count + 1))
done
shopt -u nullglob

log "installed $count skill(s) into $dest"
