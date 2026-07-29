#!/usr/bin/env zsh

# Toggle an ffmpeg recording of a screen area selected with slop.
# First call selects the area and starts recording, second call stops it.
# Bound to $mod+s in ~/.config/i3/config.

# i3 does not source .zshrc, so the brew ffmpeg is not on PATH here.
[ -d /home/linuxbrew/.linuxbrew/bin ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

local outdir="$HOME/Videos/Recordings"
local statefile="${XDG_RUNTIME_DIR:-/tmp}/i3-screenrecord.state"
local logfile="${XDG_CACHE_HOME:-$HOME/.cache}/screenrecord.log"

# The state file holds the ffmpeg pid and the file it is writing, one per line
function sr_running() {
	local pid
	[ -f "$statefile" ] || return 1
	read -r pid < "$statefile"
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

function sr_start() {
	local geometry x y w h
	# %x %y are the top-left corner, %w %h the size -- slop exits non-zero
	# when the selection is cancelled, in which case we do nothing.
	geometry=$(slop -f '%x %y %w %h') || return 1
	read -r x y w h <<< "$geometry"

	# libx264 with yuv420p needs even dimensions
	w=$(( w - w % 2 ))
	h=$(( h - h % 2 ))

	mkdir -p "$outdir"
	local out="$outdir/Recording-$(date +%Y-%m-%dT%H:%M:%S).mp4"

	# &! detaches ffmpeg so it survives this script exiting
	ffmpeg -nostdin -loglevel warning \
		-f x11grab -framerate 30 -video_size "${w}x${h}" -i "$DISPLAY+$x,$y" \
		-c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p \
		"$out" >> "$logfile" 2>&1 &!

	printf '%s\n%s\n' "$!" "$out" > "$statefile"
	notify-send "Recording ${w}x${h}" "$out"
}

function sr_stop() {
	local pid file
	{ read -r pid; read -r file; } < "$statefile"
	rm -f "$statefile"

	# SIGINT, not SIGTERM: ffmpeg flushes and closes the container on it,
	# otherwise the mp4 is left without a moov atom and won't play.
	kill -INT "$pid" 2>/dev/null

	local i
	for i in {1..50}; do
		kill -0 "$pid" 2>/dev/null || break
		sleep 0.1
	done

	if kill -0 "$pid" 2>/dev/null; then
		kill -KILL "$pid" 2>/dev/null
		notify-send -u critical "Recording killed" "$file may be broken"
		return 1
	fi

	notify-send "Recording saved" "$file"
}

if sr_running; then
	sr_stop
else
	rm -f "$statefile"
	sr_start
fi
