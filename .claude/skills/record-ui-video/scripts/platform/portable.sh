#!/usr/bin/env bash
#
# The portable platform: host facts only, no virtual display and no grab.
#
# It fits every host, so it is the last candidate in PLATFORM_CANDIDATES and the one that answers
# when no other file does. It knows how to find the dev server and nothing else, so `record.sh`
# records with Playwright's own recorder: no audio, about 25 fps, and a frame only when the page
# changes. Write a file with native capture for your system when you want the full quality.
#
# Sourced by platform.sh, which documents the contract. Run it with `detect` to ask whether it fits
# the host; that is what the loader does before it sources anything.

PLATFORM_ID='portable'
PLATFORM_NAME='no virtual display'
# No display and no grab, so record.sh falls back to Playwright's recorder.
PLATFORM_CAPTURE='none'

# The one thing this file needs is a `ps` that prints another process's environment.
platform_detect() {
	if ! command -v ps >/dev/null; then
		echo 'the host has no ps' >&2
		return 1
	fi
	return 0
}

# --- preflight rows -------------------------------------------------------------------------

# Nothing to check: there is no display to start and no device to grab. Report the fallback once,
# as ABSENT, so the preflight says why the recording will look the way it does.
platform_check_capture() {
	printf 'ABSENT|no platform file gives %s a virtual display||%s\n' \
		"$(uname -s)" \
		"For a full-rate capture with sound, add a platform file for $(uname -s) under scripts/platform/. platform.sh documents the contract."
}

platform_check_audio() {
	printf 'ABSENT|no audio capture without a native display|%s|\n' \
		"Playwright's recorder writes no audio track; pass --no-audio to silence the warning"
}

# --- finding the dev server -----------------------------------------------------------------

# One "port|mongo_url|meteor_pwd|pid" line per candidate process, deduplicated.
#
# `ps eww` prints each process's environment after its command line, on Linux and on macOS alike,
# for the processes this user owns. That is best effort: a value that holds a space breaks the
# parse. ROOT_URL, MONGO_URL and PWD hold none in practice, and `record.sh --port --mongo-url`
# overrides the lookup when they do.
#
# Take the port from ROOT_URL, not from PORT. In dev, meteor puts a proxy on the port you asked for
# and runs the inner app server on a port of its own choosing, and the inner process carries that
# private port in PORT. ROOT_URL holds the port a browser must use, in every process.
platform_list_server_processes() {
	ps eww -A -o pid=,command= 2>/dev/null |
		awk '
			/ROOT_URL=/ {
				pid = $1
				root_url = ""; port = ""; mongo = ""; app_pwd = ""
				for (i = 2; i <= NF; i++) {
					if ($i ~ /^ROOT_URL=/) { root_url = substr($i, 10) }
					else if ($i ~ /^MONGO_URL=/) { mongo = substr($i, 11) }
					else if ($i ~ /^PORT=/) { port = substr($i, 6) }
					else if ($i ~ /^PWD=/) { app_pwd = substr($i, 5) }
				}
				if (app_pwd !~ /\/apps\/meteor$/) { next }
				if (match(root_url, /:[0-9]+/)) {
					port = substr(root_url, RSTART + 1, RLENGTH - 1)
				}
				if (port == "") { next }
				print port "|" mongo "|" app_pwd "|" pid
			}
		' | sort -t'|' -k1,3 -u | awk -F'|' '!seen[$1"|"$3]++'
}

# --- capture ------------------------------------------------------------------------------------

# There is no display to start. Say so plainly: record.sh only calls this when someone forced
# `--strategy native` on a host that cannot do it.
platform_display_start() {
	echo "portable: this host has no virtual display, so it cannot capture one. Drop --strategy native." >&2
	return 1
}

platform_display_stop() { return 0; }

platform_capture_input() {
	echo 'portable: this host has no display to grab.' >&2
	return 1
}

platform_screen_input() {
	echo 'portable: this host has no display to grab.' >&2
	return 1
}

# --- audio ----------------------------------------------------------------------------------------

PLATFORM_AUDIO_PID=''
PLATFORM_AUDIO_LABEL=''
PLATFORM_AUDIO_INPUT=()
PLATFORM_AUDIO_UNAVAILABLE='this host has no audio capture'

platform_audio_open() { return 1; }
platform_audio_start() { return 0; }
platform_audio_close() { return 0; }

# Run with `detect` instead of sourced: answer whether this platform fits, and nothing else.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	case "${1:-}" in
	detect) platform_detect ;;
	*)
		echo "portable.sh: source this file, or run it with 'detect'." >&2
		exit 2
		;;
	esac
fi
