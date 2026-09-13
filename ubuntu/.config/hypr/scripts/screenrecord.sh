#!/usr/bin/env zsh

# Toggle a recording of a screen area selected with slurp.
# First call selects the area and starts recording, second call stops it.
# Bound to SUPER + S in ~/.config/hypr/bindings.conf.
#
# The Wayland port of ~/.config/i3/scripts/screenrecord.sh. slurp replaces
# slop and wf-recorder replaces ffmpeg with x11grab; the toggle, the state
# file and the stop signal are unchanged. wf-recorder lives in /usr/bin, so
# this needs no PATH fix -- the i3 copy needs one for the brew ffmpeg.

local outdir="$HOME/Videos/Recordings"
local statefile="${XDG_RUNTIME_DIR:-/tmp}/hypr-screenrecord.state"
local logfile="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-screenrecord.log"

# The state file holds the wf-recorder pid and the file it is writing, one per line
function sr_running() {
	local pid
	[ -f "$statefile" ] || return 1
	read -r pid < "$statefile"
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

function sr_start() {
	local geometry rest size x y w h
	# slurp prints "X,Y WxH", which is the format wf-recorder -g takes. It
	# exits non-zero when the selection is cancelled, so we do nothing then.
	# A region has to stay on one monitor: wf-recorder records one output.
	geometry=$(slurp) || return 1

	x=${geometry%%,*}
	rest=${geometry#*,}
	y=${rest%% *}
	size=${geometry##* }
	w=${size%%x*}
	h=${size##*x}

	# libx264 with yuv420p needs even dimensions
	w=$(( w - w % 2 ))
	h=$(( h - h % 2 ))

	mkdir -p "$outdir"
	local out="$outdir/Recording-$(date +%Y-%m-%dT%H:%M:%S).mp4"

	# &! detaches wf-recorder so it survives this script exiting
	wf-recorder -g "$x,$y ${w}x${h}" -f "$out" >> "$logfile" 2>&1 &!

	printf '%s\n%s\n' "$!" "$out" > "$statefile"
	notify-send "Recording ${w}x${h}" "$out"
}

function sr_stop() {
	local pid file
	{ read -r pid; read -r file; } < "$statefile"
	rm -f "$statefile"

	# SIGINT, not SIGTERM: wf-recorder flushes and closes the container on it,
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
