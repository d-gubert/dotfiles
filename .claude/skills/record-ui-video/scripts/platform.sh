#!/usr/bin/env bash
#
# Load the platform layer. Source this file; do not run it.
#
# Everything that differs between operating systems lives in `platform/<id>.sh`: how to find the
# running dev servers, how to give the browser a display of its own, how to capture that display,
# and how to route the app's audio. The rest of the skill calls the functions below and never names
# an operating system, a display server or a capture device.
#
# The contract has two halves:
#
#   Host facts, which every platform file must implement.
#     platform_detect                      0 when the file fits this host; the reason on stderr if not
#     platform_list_server_processes       one "port|mongo_url|meteor_pwd|pid" line per candidate
#
#   Native capture, which a platform file implements only when the host can run it. A file that
#   cannot says so with PLATFORM_CAPTURE='none', and the skill records with Playwright's own
#   recorder instead. It still implements these, to report ABSENT and to fail with a clear reason.
#     platform_check_capture               preflight rows for the display and the capture tools
#     platform_check_audio                 preflight rows for the audio tools (optional feature)
#     platform_display_start W H LOG       a display of W x H; sets PLATFORM_DISPLAY_PID
#     platform_display_stop                tear it down
#     platform_capture_input FPS W H X Y   ffmpeg input args for that rectangle, one per line
#     platform_screen_input W H            ffmpeg input args for one whole-screen frame
#     platform_audio_open FIFO TAG         route the app's audio; 1 when the host cannot
#     platform_audio_start                 start the writer; sets PLATFORM_AUDIO_PID
#     platform_audio_close                 stop the writer and undo the routing
#
# After sourcing:
#   PLATFORM_ID       the platform in use, or '' when none of them fits this host
#   PLATFORM_NAME     a human name for it
#   PLATFORM_CAPTURE  'native' when this host can grab a virtual display, 'none' when it cannot
#   PLATFORM_REASON   why none fits, when PLATFORM_ID is empty
#
# A preflight row is `STATUS|label|info|fix`, with STATUS one of OK, MISSING or ABSENT. ABSENT means
# an optional feature is unavailable, and never fails the preflight.
#
# To add native capture for a system: copy `platform/linux-x11.sh`, implement the same functions,
# and add its id to PLATFORM_CANDIDATES before `portable`. Nothing outside `platform/` changes.
#
# `portable` is the last candidate and fits every host. It knows host facts only, so it records with
# Playwright's recorder. A new file that beats it must come earlier in the list.

PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform"
PLATFORM_CANDIDATES=(linux-x11 portable)

PLATFORM_ID=''
PLATFORM_NAME=''
PLATFORM_CAPTURE='none'
PLATFORM_REASON=''

# RECORD_PLATFORM forces one candidate, so you can exercise the fallback on a host that would
# otherwise pick a native one.
if [ -n "${RECORD_PLATFORM:-}" ]; then
	PLATFORM_CANDIDATES=("$RECORD_PLATFORM")
fi

# Ask each candidate whether it fits, by running it rather than sourcing it, so a file that does not
# fit leaves no functions behind. Source only the one that answers yes.
for _platform_candidate in "${PLATFORM_CANDIDATES[@]}"; do
	_platform_file="$PLATFORM_DIR/$_platform_candidate.sh"
	[ -r "$_platform_file" ] || continue
	if _platform_why=$(bash "$_platform_file" detect 2>&1); then
		# shellcheck disable=SC1090
		. "$_platform_file"
		break
	fi
	PLATFORM_REASON="${PLATFORM_REASON:+$PLATFORM_REASON; }$_platform_candidate: $_platform_why"
done
unset _platform_candidate _platform_file _platform_why

if [ -z "$PLATFORM_ID" ] && [ -z "$PLATFORM_REASON" ]; then
	PLATFORM_REASON="no platform file under $PLATFORM_DIR"
fi

# The one-line summary a script prints when it has to give up.
platform_unsupported_message() {
	printf 'no platform file fits this host (tried %s). %s.\n' \
		"$(printf '%s, ' "${PLATFORM_CANDIDATES[@]}" | sed 's/, $//')" "$PLATFORM_REASON"
}

# Whether this host can record the native way: the platform file claims it, and every tool it needs
# is there. Read the rows into a variable first - a pipe into `grep -q` would report the SIGPIPE of
# the left side under `pipefail`, not the answer.
platform_capture_ready() {
	local rows
	[ "$PLATFORM_CAPTURE" = native ] || return 1
	rows=$(platform_check_capture)
	case "$rows" in
	*'MISSING|'*) return 1 ;;
	esac
	return 0
}
