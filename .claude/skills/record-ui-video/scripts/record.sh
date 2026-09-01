#!/usr/bin/env bash
#
# Run one recording spec, then transcode the capture to MP4 and extract frames to check it.
#
# It reads the port and the Mongo connection string from the server that serves this worktree,
# so you never pass them by hand and never record against another worktree's server.
#
# Usage:
#   record.sh tests/e2e/demos/my-demo.spec.ts
#   record.sh apps/meteor/tests/e2e/demos/my-demo.spec.ts --name my-demo
#
# Options:
#   --name NAME        basename of the output files (default: the spec's name without -demo.spec.ts)
#   --out-dir DIR      where the mp4 and webm go (default: the repo root)
#   --port N           override the discovered port
#   --mongo-url URL    override the discovered MONGO_URL
#   --frames-dir DIR   where the check frames go (default: a temp dir; the path is printed)
#   --frame-every N    seconds between check frames (default: 3)
#   --keep-previous    do not delete this spec's earlier playwright output first
#
# Every path it prints is absolute, so a later command cannot be confused by a changed cwd.
#
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/apps/meteor" ]; then
	echo 'record.sh: run this from inside a Rocket.Chat worktree.' >&2
	exit 2
fi

SPEC=''
NAME=''
OUT_DIR="$REPO_ROOT"
PORT=''
MONGO_URL=''
FRAMES_DIR=''
FRAME_EVERY=3
KEEP_PREVIOUS=0

while [ $# -gt 0 ]; do
	case "$1" in
	--name)
		NAME=$2
		shift 2
		;;
	--out-dir)
		OUT_DIR=$2
		shift 2
		;;
	--port)
		PORT=$2
		shift 2
		;;
	--mongo-url)
		MONGO_URL=$2
		shift 2
		;;
	--frames-dir)
		FRAMES_DIR=$2
		shift 2
		;;
	--frame-every)
		FRAME_EVERY=$2
		shift 2
		;;
	--keep-previous)
		KEEP_PREVIOUS=1
		shift
		;;
	-h | --help)
		sed -n '2,24p' "$0"
		exit 0
		;;
	-*)
		echo "record.sh: unknown option '$1'" >&2
		exit 2
		;;
	*)
		SPEC=$1
		shift
		;;
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

if [ -z "$NAME" ]; then
	NAME=$(basename "$SPEC_ABS")
	NAME=${NAME%.spec.ts}
fi

# --- resolve the server ----------------------------------------------------------------------
if [ -z "$PORT" ] || [ -z "$MONGO_URL" ]; then
	if server_env=$("$SCRIPT_DIR/find-server.sh" --env 2>/dev/null); then
		eval "$server_env"
		[ -n "$PORT" ] || PORT=$SERVER_PORT
		[ -n "$MONGO_URL" ] || MONGO_URL=$SERVER_MONGO_URL
		echo "server: port $PORT, version $SERVER_VERSION, branch $SERVER_BRANCH"
	else
		echo 'record.sh: no dev server serves this worktree. Run preflight.sh for the detail.' >&2
		exit 1
	fi
fi

PLAYWRIGHT_OUT="$REPO_ROOT/apps/meteor/tests/e2e/.playwright"
if [ "$KEEP_PREVIOUS" -eq 0 ]; then
	spec_slug=$(basename "$(dirname "$SPEC_REL")")-$(basename "$SPEC_ABS" .spec.ts)
	rm -rf "$PLAYWRIGHT_OUT/$spec_slug"* 2>/dev/null
fi

# --- run -------------------------------------------------------------------------------------
LOG=$(mktemp -t record-ui-video-XXXXXX.log)
echo "spec:   $SPEC_REL"
echo "log:    $LOG"
echo

(
	cd "$REPO_ROOT/apps/meteor" &&
		IS_EE=true BASE_URL="http://localhost:$PORT" MONGO_URL="$MONGO_URL" \
			yarn test:e2e "$SPEC_REL"
) >"$LOG" 2>&1
RUN_EXIT=$?

tail -30 "$LOG"
echo

# The spec forces `video: { mode: 'on' }`, so a capture exists whether the run passed or failed.
WEBM=$(find "$PLAYWRIGHT_OUT" -name 'video.webm' -newer "$LOG" -print 2>/dev/null | head -1)
if [ -z "$WEBM" ]; then
	WEBM=$(find "$PLAYWRIGHT_OUT" -name 'video.webm' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -z "$WEBM" ]; then
	echo 'record.sh: the run produced no video.' >&2
	echo "record.sh: read the full log at $LOG" >&2
	exit 1
fi

if [ "$RUN_EXIT" -ne 0 ]; then
	echo 'record.sh: WARNING - the spec failed. The video exists but may show a broken screen.'
	echo "record.sh: read the full log at $LOG"
	echo
fi

# --- deliver ---------------------------------------------------------------------------------
mkdir -p "$OUT_DIR"
OUT_DIR_ABS=$(cd "$OUT_DIR" && pwd)
OUT_WEBM="$OUT_DIR_ABS/$NAME.webm"
OUT_MP4="$OUT_DIR_ABS/$NAME.mp4"
cp "$WEBM" "$OUT_WEBM"
echo "webm:   $OUT_WEBM"

if command -v ffmpeg >/dev/null; then
	# pad to even dimensions because libx264 with yuv420p rejects an odd width or height.
	ffmpeg -y -i "$OUT_WEBM" -movflags +faststart -pix_fmt yuv420p \
		-vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' -c:v libx264 -crf 20 -preset veryfast \
		"$OUT_MP4" >>"$LOG" 2>&1
	if [ -s "$OUT_MP4" ]; then
		echo "mp4:    $OUT_MP4"
		if command -v ffprobe >/dev/null; then
			ffprobe -v error -select_streams v:0 \
				-show_entries stream=width,height,avg_frame_rate \
				-show_entries format=duration -of default=nw=1 "$OUT_MP4" |
				sed 's/^/        /'
		fi
	else
		echo 'record.sh: the transcode failed; the webm is still good.' >&2
	fi

	# Frames to verify the content. Read a few before you hand the video over.
	[ -n "$FRAMES_DIR" ] || FRAMES_DIR=$(mktemp -d -t record-ui-video-frames-XXXXXX)
	mkdir -p "$FRAMES_DIR"
	rm -f "$FRAMES_DIR"/f_*.png
	ffmpeg -y -i "$OUT_MP4" -vf "fps=1/$FRAME_EVERY" "$FRAMES_DIR/f_%02d.png" >>"$LOG" 2>&1
	frame_count=$(find "$FRAMES_DIR" -name 'f_*.png' | wc -l | tr -d ' ')
	echo "frames: $FRAMES_DIR ($frame_count png, one every ${FRAME_EVERY}s) - Read a few to verify"
else
	echo 'record.sh: ffmpeg is absent, so there is no mp4 and no frame check.'
fi

exit "$RUN_EXIT"
