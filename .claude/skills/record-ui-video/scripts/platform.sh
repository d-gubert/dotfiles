#!/usr/bin/env bash
#
# Load the platform layer. Source this file; do not run it.
#
# Everything that differs between operating systems lives in `platform/<id>.sh`: how to find the
# running dev servers, how to give the browser a display of its own, how to capture that display,
# and how to route the app's audio. The rest of the skill calls the functions below and never names
# an operating system, a display server or a capture device.
#
# After sourcing:
#   PLATFORM_ID      the platform in use, or '' when none of them fits this host
#   PLATFORM_NAME    a human name for it
#   PLATFORM_REASON  why none fits, when PLATFORM_ID is empty
#
# The contract every platform file implements:
#
#   platform_detect                      0 when the file fits this host; the reason on stderr if not
#   platform_check_capture               preflight rows for the display and the capture tools
#   platform_check_audio                 preflight rows for the audio tools (optional feature)
#   platform_list_server_processes       one "port|mongo_url|meteor_pwd|pid" line per candidate
#   platform_display_start W H LOG       a display of W x H; sets PLATFORM_DISPLAY_PID
#   platform_display_stop                tear it down
#   platform_capture_input FPS W H X Y   ffmpeg input args for that rectangle, one per line
#   platform_screen_input W H            ffmpeg input args for one whole-screen frame
#   platform_audio_open FIFO TAG         route the app's audio; 1 when the host cannot
#   platform_audio_start                 start the writer; sets PLATFORM_AUDIO_PID
#   platform_audio_close                 stop the writer and undo the routing
#
# A preflight row is `STATUS|label|info|fix`, with STATUS one of OK, MISSING or ABSENT. ABSENT means
# an optional feature is unavailable, and never fails the preflight.
#
# To add a platform: copy `platform/linux-x11.sh`, implement the same functions, and add its id to
# PLATFORM_CANDIDATES. Nothing outside `platform/` changes.

PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform"
PLATFORM_CANDIDATES=(linux-x11)

PLATFORM_ID=''
PLATFORM_NAME=''
PLATFORM_REASON=''

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
	printf 'this skill supports %s only. Here: %s.\n' \
		"$(printf '%s, ' "${PLATFORM_CANDIDATES[@]}" | sed 's/, $//')" "$PLATFORM_REASON"
}
