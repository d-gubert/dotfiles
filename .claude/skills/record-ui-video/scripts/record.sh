#!/usr/bin/env bash
#
# Record one demo spec as a video: a headed Chromium on a virtual display, captured by ffmpeg.
#
# Why not Playwright's own recorder: it captures a frame only when the compositor changes, caps
# around 25 fps, drops frames during idle beats and records no audio. ffmpeg grabs the X display at
# a constant rate and mixes in whatever the browser plays, so the motion is smooth and a ringtone
# is on the tape.
#
# What it does, in order:
#   1. finds the running dev server (port, MONGO_URL)
#   2. starts a display of its own, through the platform layer
#   3. calibrates once per Chromium build: the --window-size that gives an exact content area, and
#      where that content area sits on the screen (cached under ~/.cache/record-ui-video)
#   4. gives the browser a private PulseAudio sink, so it records the app and nothing else
#   5. captures the page rectangle with ffmpeg while the spec drives the browser
#   6. trims the black head and tail, encodes an MP4, extracts check frames
#
# Usage:
#   record.sh tests/e2e/demos/my-demo.spec.ts
#   record.sh apps/meteor/tests/e2e/demos/my-demo.spec.ts --fps 30 --no-audio
#
# Options:
#   --name NAME        basename of the output files (default: the spec's file name)
#   --out-dir DIR      where the mp4 goes (default: the repo root)
#   --viewport WxH     page size to record (default: read from the spec, else 1280x720)
#   --fps N            capture frame rate (default: 60)
#   --no-audio         do not capture audio
#   --no-trim          keep the black head and tail instead of trimming them
#   --keep-raw         keep the lossless capture next to the mp4
#   --recalibrate      ignore the cached window geometry and measure it again
#   --port N           override the discovered port
#   --mongo-url URL    override the discovered MONGO_URL
#   --frames-dir DIR   where the check frames go (default: a temp dir; the path is printed)
#   --frame-every N    seconds between check frames (default: 3)
#
# Every path it prints is absolute, so a later command cannot be confused by a changed cwd.
#
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# The display, the grab and the audio routing all differ per system; platform.sh loads the file
# under platform/ that fits this host, and this script only calls its functions.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform.sh"
if [ -z "$PLATFORM_ID" ]; then
	echo "record.sh: $(platform_unsupported_message)" >&2
	exit 1
fi
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/apps/meteor" ]; then
	echo 'record.sh: run this from inside a Rocket.Chat checkout.' >&2
	exit 2
fi

SPEC=''
NAME=''
OUT_DIR="$REPO_ROOT"
VIEWPORT=''
FPS=60
WITH_AUDIO=1
TRIM=1
KEEP_RAW=0
RECALIBRATE=0
PORT=''
MONGO_URL=''
FRAMES_DIR=''
FRAME_EVERY=3

while [ $# -gt 0 ]; do
	case "$1" in
	--name) NAME=$2; shift 2 ;;
	--out-dir) OUT_DIR=$2; shift 2 ;;
	--viewport) VIEWPORT=$2; shift 2 ;;
	--fps) FPS=$2; shift 2 ;;
	--no-audio) WITH_AUDIO=0; shift ;;
	--no-trim) TRIM=0; shift ;;
	--keep-raw) KEEP_RAW=1; shift ;;
	--recalibrate) RECALIBRATE=1; shift ;;
	--port) PORT=$2; shift 2 ;;
	--mongo-url) MONGO_URL=$2; shift 2 ;;
	--frames-dir) FRAMES_DIR=$2; shift 2 ;;
	--frame-every) FRAME_EVERY=$2; shift 2 ;;
	-h | --help) sed -n '2,37p' "$0"; exit 0 ;;
	-*) echo "record.sh: unknown option '$1'" >&2; exit 2 ;;
	*) SPEC=$1; shift ;;
	esac
done

if [ -z "$SPEC" ]; then
	echo 'record.sh: pass the path of the spec to record.' >&2
	exit 2
fi

# Accept a repo-relative, an apps/meteor-relative, or an absolute spec path.
if [ -f "$SPEC" ]; then
	SPEC_ABS=$(cd "$(dirname "$SPEC")" && pwd)/$(basename "$SPEC")
elif [ -f "$REPO_ROOT/$SPEC" ]; then
	SPEC_ABS="$REPO_ROOT/$SPEC"
elif [ -f "$REPO_ROOT/apps/meteor/$SPEC" ]; then
	SPEC_ABS="$REPO_ROOT/apps/meteor/$SPEC"
else
	echo "record.sh: no spec at '$SPEC'." >&2
	exit 2
fi
SPEC_REL=${SPEC_ABS#"$REPO_ROOT/apps/meteor/"}
[ -n "$NAME" ] || NAME=$(basename "$SPEC_ABS" .spec.ts)

need() {
	command -v "$1" >/dev/null || {
		echo "record.sh: $1 is not on PATH. Run preflight.sh." >&2
		exit 1
	}
}
need ffmpeg
need node

# --- the size to record ------------------------------------------------------------------------
# The spec declares it; read it from there so the two cannot drift apart.
if [ -z "$VIEWPORT" ]; then
	VIEWPORT=$(sed -n 's/.*RECORD_VIEWPORT *= *.\([0-9]\{2,\}x[0-9]\{2,\}\).*/\1/p' "$SPEC_ABS" | head -1)
fi
[ -n "$VIEWPORT" ] || VIEWPORT=1280x720
VIEW_W=${VIEWPORT%x*}
VIEW_H=${VIEWPORT#*x}

# --- resolve the server -------------------------------------------------------------------------
if [ -z "$PORT" ] || [ -z "$MONGO_URL" ]; then
	if server_env=$("$SCRIPT_DIR/find-server.sh" --env ${PORT:+--port "$PORT"}); then
		eval "$server_env"
		[ -n "$PORT" ] || PORT=$SERVER_PORT
		[ -n "$MONGO_URL" ] || MONGO_URL=$SERVER_MONGO_URL
		echo "server: port $PORT, version $SERVER_VERSION, branch $SERVER_BRANCH"
	else
		echo 'record.sh: no dev server to record against. Run preflight.sh for the detail.' >&2
		exit 1
	fi
fi

TMP_DIR=$(mktemp -d -t record-ui-video-XXXXXX)
LOG="$TMP_DIR/record.log"
RAW="$TMP_DIR/capture.mkv"
FIFO="$TMP_DIR/audio.pcm"

FFMPEG_PID=''

cleanup() {
	[ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null
	platform_audio_close
	platform_display_stop
}
trap cleanup EXIT INT TERM

# --- the virtual display ------------------------------------------------------------------------
# A display of its own, so the recording cannot catch the user's desktop and a stray window cannot
# cover the browser. Room around the window for the browser frame; the capture crops back to the
# page.
SCREEN_W=$((VIEW_W + 80))
SCREEN_H=$((VIEW_H + 240))
platform_display_start "$SCREEN_W" "$SCREEN_H" "$TMP_DIR/display.log" || exit 1

# --- window geometry ----------------------------------------------------------------------------
# No window manager runs on that display, so nobody resizes the browser: the spec must ask for a
# --window-size that leaves an exact content area, and ffmpeg must know where that area starts.
# Both are properties of the Chromium build, so measure once and cache.
PW_VERSION=$(node -e "process.stdout.write(require('$REPO_ROOT/apps/meteor/node_modules/playwright/package.json').version)" 2>/dev/null || echo unknown)
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/record-ui-video"
CACHE_FILE="$CACHE_DIR/geometry-$PW_VERSION-$VIEWPORT.env"
mkdir -p "$CACHE_DIR"

if [ "$RECALIBRATE" -eq 1 ] || [ ! -f "$CACHE_FILE" ]; then
	echo "calibrate: measuring the browser frame for playwright $PW_VERSION at $VIEWPORT"
	# calibrate.js launches the browser, paints a magenta page, grabs a frame of it and prints the
	# geometry as shell assignments. Write the cache only after it succeeds.
	mapfile -t SCREEN_INPUT < <(platform_screen_input "$SCREEN_W" "$SCREEN_H")
	if ! NODE_PATH="$REPO_ROOT/apps/meteor/node_modules" \
		node "$SCRIPT_DIR/calibrate.js" "$VIEWPORT" "${SCREEN_W}x${SCREEN_H}" \
		-- "${SCREEN_INPUT[@]}" >"$TMP_DIR/geometry.env"; then
		echo 'record.sh: the calibration failed, so the window geometry is unknown.' >&2
		exit 1
	fi
	mv "$TMP_DIR/geometry.env" "$CACHE_FILE"
fi
# shellcheck disable=SC1090
. "$CACHE_FILE"

if [ "$CROP_W" != "$VIEW_W" ] || [ "$CROP_H" != "$VIEW_H" ]; then
	echo "record.sh: WARNING - the page measures ${CROP_W}x${CROP_H}, not $VIEWPORT. Recording what is there."
fi
# libx264 with yuv420p rejects an odd width or height.
CROP_W=$((CROP_W - CROP_W % 2))
CROP_H=$((CROP_H - CROP_H % 2))
echo "display: $PLATFORM_ID ${SCREEN_W}x${SCREEN_H}, window $WINDOW_SIZE, page ${CROP_W}x${CROP_H}+${CROP_X}+${CROP_Y}"

# --- the app's own audio --------------------------------------------------------------------------
# The platform routes what the browser plays into a stream of its own, so the recording catches the
# app and nothing else the machine is playing, and the user hears nothing.
AUDIO_ARGS=()
AUDIO_CODEC=(-an)
AUDIO_OUT=(-an)
if [ "$WITH_AUDIO" -eq 1 ]; then
	if platform_audio_open "$FIFO" "$$"; then
		AUDIO_ARGS=("${PLATFORM_AUDIO_INPUT[@]}")
		AUDIO_CODEC=(-c:a pcm_s16le)
		AUDIO_OUT=(-c:a aac -b:a 128k)
		echo "audio:   $PLATFORM_AUDIO_LABEL"
	else
		echo "audio:   off ($PLATFORM_AUDIO_UNAVAILABLE)"
		WITH_AUDIO=0
	fi
else
	echo 'audio:   off (--no-audio)'
fi

# --- capture ----------------------------------------------------------------------------------
# Grab only the page rectangle. ultrafast keeps the capture cheap; the delivered mp4 is a second,
# slower pass over this file.
echo "spec:    $SPEC_REL"
echo "log:     $LOG"
echo
mapfile -t CAPTURE_INPUT < <(platform_capture_input "$FPS" "$CROP_W" "$CROP_H" "$CROP_X" "$CROP_Y")
ffmpeg -y -hide_banner -nostdin -loglevel warning -stats \
	"${AUDIO_ARGS[@]}" \
	"${CAPTURE_INPUT[@]}" \
	-c:v libx264 -preset ultrafast -qp 18 -pix_fmt yuv420p \
	"${AUDIO_CODEC[@]}" \
	"$RAW" >>"$LOG" 2>&1 &
FFMPEG_PID=$!

# ffmpeg may block on the audio stream until a writer appears, so start the writer now: both
# streams then begin together and stay in step.
if [ "$WITH_AUDIO" -eq 1 ]; then
	platform_audio_start "$LOG"
fi
sleep 1

if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
	echo 'record.sh: ffmpeg died at once. The log holds the reason.' >&2
	tail -20 "$LOG" >&2
	exit 1
fi

# --- run the spec -------------------------------------------------------------------------------
(
	cd "$REPO_ROOT/apps/meteor" &&
		IS_EE=true BASE_URL="http://localhost:$PORT" MONGO_URL="$MONGO_URL" \
			RECORD_WINDOW_SIZE="$WINDOW_SIZE" \
			yarn test:e2e "$SPEC_REL"
) >>"$LOG" 2>&1
RUN_EXIT=$?

# Let the last frames land, then close the file cleanly. Stop the audio first: killing ffmpeg while
# the writer still runs leaves it shouting about a broken pipe.
sleep 1
if [ "$WITH_AUDIO" -eq 1 ]; then
	platform_audio_close
	sleep 0.3
fi
kill -INT "$FFMPEG_PID" 2>/dev/null
wait "$FFMPEG_PID" 2>/dev/null
FFMPEG_PID=''

grep -E '^  (✓|✘|×|✗|-)|passed|failed' "$LOG" | tail -12
echo

if [ ! -s "$RAW" ]; then
	echo 'record.sh: the capture is empty.' >&2
	echo "record.sh: read the full log at $LOG" >&2
	cp "$LOG" "/tmp/$(basename "$LOG")" 2>/dev/null
	exit 1
fi
if [ "$RUN_EXIT" -ne 0 ]; then
	echo 'record.sh: WARNING - the spec failed. The video exists but may show a broken screen.'
	echo "record.sh: read the full log at $LOG"
	echo
fi

# --- trim the black head and tail -----------------------------------------------------------------
# The capture starts before the browser maps its window and runs on after it closes; both ends are
# the bare X root window, which is pure black. Nothing the app draws is pure black, so this is safe.
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
TRIM_ARGS=()
if [ "$TRIM" -eq 1 ]; then
	black=$(ffmpeg -hide_banner -nostdin -i "$RAW" -vf 'blackdetect=d=0.15:pix_th=0.00' -an -f null - 2>&1 |
		sed -n 's/.*black_start:\([0-9.]*\) black_end:\([0-9.]*\).*/\1 \2/p')
	head_end=$(printf '%s\n' "$black" | awk '$1 < 0.5 { print $2; exit }')
	tail_start=$(printf '%s\n' "$black" | awk -v d="$DURATION" '$2 > d - 0.5 { print $1; exit }')
	[ -n "$head_end" ] && TRIM_ARGS+=(-ss "$head_end")
	[ -n "$tail_start" ] && TRIM_ARGS+=(-to "$tail_start")
fi

# --- deliver ------------------------------------------------------------------------------------
mkdir -p "$OUT_DIR"
OUT_DIR_ABS=$(cd "$OUT_DIR" && pwd)
OUT_MP4="$OUT_DIR_ABS/$NAME.mp4"

ffmpeg -y -hide_banner -nostdin -loglevel error -i "$RAW" "${TRIM_ARGS[@]}" \
	-c:v libx264 -crf 20 -preset veryfast -pix_fmt yuv420p -movflags +faststart \
	"${AUDIO_OUT[@]}" \
	"$OUT_MP4" >>"$LOG" 2>&1

if [ ! -s "$OUT_MP4" ]; then
	echo 'record.sh: the encode failed.' >&2
	tail -20 "$LOG" >&2
	cp "$RAW" "$OUT_DIR_ABS/$NAME.raw.mkv" && echo "record.sh: the raw capture is at $OUT_DIR_ABS/$NAME.raw.mkv" >&2
	exit 1
fi

echo "mp4:     $OUT_MP4"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate \
	-show_entries format=duration -of default=nw=1 "$OUT_MP4" | sed 's/^/         /'

# What the capture really managed. A big drop count means the machine could not grab and encode at
# the asked rate: lower --fps, or take the load off the box.
stats=$(tr '\r' '\n' <"$LOG" | grep -E '^frame=' | tail -1)
dropped=$(printf '%s\n' "$stats" | sed -n 's/.*drop= *\([0-9]*\).*/\1/p')
if [ -n "${dropped:-}" ] && [ "$dropped" -gt 0 ]; then
	echo "         capture: $FPS fps asked, $dropped frames dropped - try --fps 30"
fi

if [ "$WITH_AUDIO" -eq 1 ]; then
	level=$(ffmpeg -hide_banner -nostdin -i "$OUT_MP4" -af volumedetect -f null - 2>&1 |
		sed -n 's/.*max_volume: \(.*\)/\1/p' | head -1)
	case "$level" in
	'' | '-91.0 dB' | '-inf dB') echo '         audio: silent - the scenario played nothing' ;;
	*) echo "         audio: peak $level" ;;
	esac
fi

if [ "$KEEP_RAW" -eq 1 ]; then
	cp "$RAW" "$OUT_DIR_ABS/$NAME.raw.mkv"
	echo "raw:     $OUT_DIR_ABS/$NAME.raw.mkv"
fi

# Frames to verify the content. Read a few before you hand the video over.
[ -n "$FRAMES_DIR" ] || FRAMES_DIR=$(mktemp -d -t record-ui-video-frames-XXXXXX)
mkdir -p "$FRAMES_DIR"
rm -f "$FRAMES_DIR"/f_*.png
ffmpeg -y -hide_banner -nostdin -loglevel error -i "$OUT_MP4" -vf "fps=1/$FRAME_EVERY" "$FRAMES_DIR/f_%02d.png" >>"$LOG" 2>&1
frame_count=$(find "$FRAMES_DIR" -name 'f_*.png' | wc -l | tr -d ' ')
echo "frames:  $FRAMES_DIR ($frame_count png, one every ${FRAME_EVERY}s) - Read a few to verify"

cp "$LOG" "/tmp/$(basename "$LOG")" 2>/dev/null && echo "log:     /tmp/$(basename "$LOG")"

exit "$RUN_EXIT"
