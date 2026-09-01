#!/usr/bin/env bash
#
# The Linux + X11 platform: an Xvfb display, ffmpeg's x11grab, a PulseAudio null sink, and /proc.
#
# Sourced by platform.sh, which documents the contract. Run it with `detect` to ask whether it fits
# the host; that is what the loader does before it sources anything.

PLATFORM_ID='linux-x11'
PLATFORM_NAME='Linux with X11'
# This host can grab a virtual display, so the recording does not need Playwright's own recorder.
PLATFORM_CAPTURE='native'

platform_detect() {
	if [ "$(uname -s)" != Linux ]; then
		echo "the host runs $(uname -s), not Linux" >&2
		return 1
	fi
	# find-server.sh reads each process's own environment out of /proc.
	if [ ! -r /proc/self/environ ]; then
		echo 'the host has no readable /proc' >&2
		return 1
	fi
	return 0
}

# --- preflight rows -------------------------------------------------------------------------

# ffmpeg grabs the X display, so it must have the x11grab device compiled in. The calibration grabs
# one frame with it too, to find where the page sits on that display.
platform_check_capture() {
	if command -v Xvfb >/dev/null; then
		printf 'OK|Xvfb (%s)||\n' "$(command -v Xvfb)"
	else
		printf 'MISSING|Xvfb is not on PATH||%s\n' \
			'Install Xvfb: `sudo apt install xvfb`. The recording runs the browser on a display of its own.'
	fi
	if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
		if ffmpeg -hide_banner -devices 2>/dev/null | grep -q x11grab; then
			printf 'OK|%s with x11grab||\n' "$(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f1-3)"
		else
			printf 'MISSING|this ffmpeg has no x11grab device||%s\n' \
				'Install an ffmpeg built with x11grab: `sudo apt install ffmpeg`.'
		fi
	else
		printf 'MISSING|ffmpeg or ffprobe is not on PATH||%s\n' \
			'Install ffmpeg: `sudo apt install ffmpeg` or `brew install ffmpeg`.'
	fi
}

# Optional. Without it the video still records, silently.
platform_check_audio() {
	if command -v pactl >/dev/null && command -v parec >/dev/null && pactl info >/dev/null 2>&1; then
		printf 'OK|%s||\n' "$(pactl info | sed -n 's/^Server Name: //p')"
	else
		printf 'ABSENT|no PulseAudio server, or pactl/parec are missing|%s|%s\n' \
			'the video records without sound; pass --no-audio to silence the warning' \
			'For sound, install pulseaudio-utils (`sudo apt install pulseaudio-utils`) and make sure a PulseAudio or PipeWire server is running for your session.'
	fi
}

# --- finding the dev server -----------------------------------------------------------------

# One "port|mongo_url|meteor_pwd|pid" line per candidate process, deduplicated. Meteor runs several
# processes that share one environment, so the same server appears many times.
#
# Take the port from ROOT_URL, not from PORT. In dev, meteor puts a proxy on the port you asked for
# and runs the inner app server on a port of its own choosing, and the inner process carries that
# private port in PORT. ROOT_URL holds the port a browser must use, in every process.
platform_list_server_processes() {
	for proc in /proc/[0-9]*; do
		pid=${proc#/proc/}
		env_data=$( (tr '\0' '\n' <"$proc/environ") 2>/dev/null ) || continue
		[ -n "$env_data" ] || continue
		case "$env_data" in
		*ROOT_URL=*) ;;
		*) continue ;;
		esac
		app_pwd=$(printf '%s\n' "$env_data" | sed -n 's/^PWD=//p' | head -1)
		case "$app_pwd" in
		*/apps/meteor) ;;
		*) continue ;;
		esac
		root_url=$(printf '%s\n' "$env_data" | sed -n 's/^ROOT_URL=//p' | head -1)
		port=$(printf '%s\n' "$root_url" | sed -n 's|^https\{0,1\}://[^:/]*:\([0-9]\{1,\}\).*|\1|p')
		# ROOT_URL without an explicit port: fall back to PORT.
		[ -n "$port" ] || port=$(printf '%s\n' "$env_data" | sed -n 's/^PORT=//p' | head -1)
		mongo=$(printf '%s\n' "$env_data" | sed -n 's/^MONGO_URL=//p' | head -1)
		[ -n "$port" ] || continue
		printf '%s|%s|%s|%s\n' "$port" "$mongo" "$app_pwd" "$pid"
	done | sort -t'|' -k1,3 -u | awk -F'|' '!seen[$1"|"$3]++'
}

# --- the display ------------------------------------------------------------------------------

PLATFORM_DISPLAY_PID=''
PLATFORM_DISPLAY_NUM=''

# A display of its own, so the recording cannot catch the user's desktop and a stray window cannot
# cover the browser. Exports DISPLAY, which is what Chromium and ffmpeg both read.
platform_display_start() {
	local width=$1 height=$2 log=$3 n
	for n in $(seq 90 120); do
		[ -e "/tmp/.X11-unix/X$n" ] && continue
		PLATFORM_DISPLAY_NUM=$n
		break
	done
	if [ -z "$PLATFORM_DISPLAY_NUM" ]; then
		echo 'linux-x11: no free X display between :90 and :120.' >&2
		return 1
	fi
	Xvfb ":$PLATFORM_DISPLAY_NUM" -screen 0 "${width}x${height}x24" -nolisten tcp >"$log" 2>&1 &
	PLATFORM_DISPLAY_PID=$!
	for _ in $(seq 1 40); do
		[ -e "/tmp/.X11-unix/X$PLATFORM_DISPLAY_NUM" ] && break
		sleep 0.25
	done
	if ! kill -0 "$PLATFORM_DISPLAY_PID" 2>/dev/null; then
		echo 'linux-x11: Xvfb did not start.' >&2
		cat "$log" >&2
		return 1
	fi
	export DISPLAY=":$PLATFORM_DISPLAY_NUM"
	PLATFORM_DISPLAY_NAME=$DISPLAY
	return 0
}

platform_display_stop() {
	[ -n "$PLATFORM_DISPLAY_PID" ] && kill "$PLATFORM_DISPLAY_PID" 2>/dev/null
	PLATFORM_DISPLAY_PID=''
	return 0
}

# --- capture ------------------------------------------------------------------------------------

# ffmpeg input args for one rectangle of the display, at a fixed frame rate.
platform_capture_input() {
	local fps=$1 width=$2 height=$3 x=$4 y=$5
	printf '%s\n' -thread_queue_size 1024 -f x11grab -draw_mouse 0 -framerate "$fps" \
		-video_size "${width}x${height}" -i "$DISPLAY+$x,$y"
}

# ffmpeg input args for one frame of the whole display, used by the crop calibration.
platform_screen_input() {
	local width=$1 height=$2
	printf '%s\n' -f x11grab -draw_mouse 0 -video_size "${width}x${height}" -i "$DISPLAY"
}

# --- audio ----------------------------------------------------------------------------------------

PLATFORM_AUDIO_PID=''
PLATFORM_AUDIO_LABEL=''
PLATFORM_AUDIO_INPUT=()
PLATFORM_AUDIO_UNAVAILABLE=''
_platform_sink_module=''
_platform_sink_name=''
_platform_fifo=''

# The browser plays into a null sink of its own. Recording that sink's monitor catches the app and
# nothing else the machine is playing, and the user hears nothing.
platform_audio_open() {
	local fifo=$1 tag=$2
	if ! { command -v pactl >/dev/null && command -v parec >/dev/null && pactl info >/dev/null 2>&1; }; then
		PLATFORM_AUDIO_UNAVAILABLE='no PulseAudio server; pactl and parec must both work'
		return 1
	fi
	_platform_sink_name="rcrec_$tag"
	_platform_sink_module=$(pactl load-module module-null-sink sink_name="$_platform_sink_name" \
		sink_properties="device.description=record-ui-video" 2>/dev/null)
	if [ -z "$_platform_sink_module" ]; then
		PLATFORM_AUDIO_UNAVAILABLE='the null sink would not load'
		return 1
	fi
	export PULSE_SINK="$_platform_sink_name"
	_platform_fifo=$fifo
	mkfifo "$fifo"
	# ffmpeg reads the fifo; parec fills it once ffmpeg has opened it.
	PLATFORM_AUDIO_INPUT=(-thread_queue_size 1024 -f s16le -ar 48000 -ac 2 -i "$fifo")
	PLATFORM_AUDIO_LABEL="$_platform_sink_name.monitor"
	return 0
}

# --latency-msec matters more than it looks. parec defaults to a buffer of about two seconds; the
# audio then reaches ffmpeg in late bursts, ffmpeg waits for the lagging stream, and x11grab drops
# three video frames out of four. A 50 ms buffer keeps the audio real-time and the capture at the
# full frame rate.
platform_audio_start() {
	local log=$1
	parec --latency-msec=50 --format=s16le --rate=48000 --channels=2 \
		-d "$_platform_sink_name.monitor" >"$_platform_fifo" 2>>"$log" &
	PLATFORM_AUDIO_PID=$!
	return 0
}

platform_audio_close() {
	[ -n "$PLATFORM_AUDIO_PID" ] && kill "$PLATFORM_AUDIO_PID" 2>/dev/null
	PLATFORM_AUDIO_PID=''
	[ -n "$_platform_sink_module" ] && pactl unload-module "$_platform_sink_module" 2>/dev/null
	_platform_sink_module=''
	[ -n "$_platform_fifo" ] && rm -f "$_platform_fifo"
	return 0
}

# Run with `detect` instead of sourced: answer whether this platform fits, and nothing else.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	case "${1:-}" in
	detect) platform_detect ;;
	*)
		echo "linux-x11.sh: source this file, or run it with 'detect'." >&2
		exit 2
		;;
	esac
fi
