#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from claude-code/post-start.sh, on every start.
#
# Installs what stage-host-config.sh copied out of your host config and
# claude-code/initialize.sh bind-mounted read-only at /opt/devbox-host-config —
# your skills and your CLAUDE.md — into the container's Claude Code config
# directory. Honours $CLAUDE_CONFIG_DIR and falls back to ~/.claude, matching the
# CLI's own resolution.
#
# Copied rather than symlinked so both survive the mount going away, and because
# the mount is read-only anyway — nothing in here can write back towards your
# host config.
#
# Runs on every start, not just onCreate, so editing a skill or the CLAUDE.md on
# the host only needs a container restart.
set -euo pipefail

staged="/opt/devbox-host-config"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
# What the previous run installed. Used to prune what has since been removed on
# the host, without touching a skill or a CLAUDE.md written directly in the
# container — those were never recorded here.
manifest="$config_dir/.host-skills.manifest"
marker="$config_dir/.host-claude-md.installed"

log() { printf '\033[1;34m[install-host-config]\033[0m %s\n' "$1"; }

if [ ! -d "$staged" ]; then
	# The mount is contributed by the same feature as this script, so its absence
	# means the container was brought up some other way (a plain
	# `docker compose up`). Leave whatever is installed alone.
	#
	# An *empty* staging directory is a different signal: the host deliberately
	# contributed nothing (an empty config, or the sync is opted out), and the
	# prunes below remove what an earlier run installed.
	log "nothing staged at $staged — skipping"
	exit 0
fi

mkdir -p "$config_dir/skills"

# --- Skills -------------------------------------------------------------------

if [ -f "$manifest" ]; then
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		[ -d "$staged/skills/$name" ] && continue
		[ -d "$config_dir/skills/$name" ] || continue
		log "removing skill '$name' — no longer on the host"
		rm -rf "${config_dir:?}/skills/$name"
	done <"$manifest"
fi

count=0
: >"$manifest"
shopt -s nullglob
for entry in "$staged"/skills/*; do
	[ -d "$entry" ] || continue
	name="$(basename "$entry")"
	# Replace rather than merge, so a file deleted from a skill on the host does
	# not survive in the container copy.
	rm -rf "${config_dir:?}/skills/$name"
	cp -R "$entry" "$config_dir/skills/$name"
	# The copy inherits the read-only mount's mode bits for directories; make our
	# own copy writable so a later run can replace it.
	chmod -R u+w "$config_dir/skills/$name"
	printf '%s\n' "$name" >>"$manifest"
	count=$((count + 1))
done
shopt -u nullglob

# --- CLAUDE.md ----------------------------------------------------------------

memory="no CLAUDE.md"
if [ -f "$staged/CLAUDE.md" ]; then
	cp "$staged/CLAUDE.md" "$config_dir/CLAUDE.md"
	# Same reason as the chmod above.
	chmod u+w "$config_dir/CLAUDE.md"
	# The marker records that this script owns the file, which is what lets the
	# branch below remove it later.
	: >"$marker"
	memory="CLAUDE.md"
elif [ -f "$marker" ]; then
	log "removing CLAUDE.md — no longer on the host"
	rm -f "$config_dir/CLAUDE.md" "$marker"
fi

log "installed $count skill(s) and $memory into $config_dir"
