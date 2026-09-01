#!/usr/bin/env bash
#
# Check every prerequisite a recording needs, in one pass, and say exactly what is missing.
#
# Checks:
#   1. workspace       - this is a git worktree that holds apps/meteor
#   2. node_modules    - dependencies are installed
#   3. built packages  - no changed package source is newer than its dist (meteor loads dist)
#   4. chromium        - the playwright browser the recording drives, headed
#   5. capture         - Xvfb for the virtual display, ffmpeg with x11grab
#   6. audio           - a PulseAudio server and parec, to record what the app plays (optional)
#   7. server          - a Rocket.Chat dev server that serves THIS worktree
#
# Usage:
#   preflight.sh              # report only; exit 0 when ready, 1 when something is missing
#   preflight.sh --install    # also install what this script can install, then re-check
#
# Ask the user before you pass --install. Two of the fixes are slow (`yarn build`, a browser
# download) and one cannot be automated at all (starting the server, which needs a port and a
# database the user chooses).
#
set -uo pipefail

DO_INSTALL=0
case "${1:-}" in
--install) DO_INSTALL=1 ;;
'' | --check) ;;
-h | --help)
	sed -n '2,22p' "$0"
	exit 0
	;;
*)
	echo "preflight.sh: unknown argument '$1'" >&2
	exit 2
	;;
esac

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')

missing=0
# Fixes this script can run itself, one shell command per line.
auto_fixes=()
# Fixes only the user can make.
manual_fixes=()

ok() { printf '  OK      %s\n' "$1"; }
bad() {
	printf '  MISSING %s\n' "$1"
	missing=1
}
info() { printf '          %s\n' "$1"; }

echo 'Recording preflight'
echo

# --- 1. workspace ----------------------------------------------------------------------------
echo '1. workspace'
if [ -z "$REPO_ROOT" ]; then
	bad 'not inside a git repository'
	manual_fixes+=('Change into a Rocket.Chat worktree and run this again.')
elif [ ! -d "$REPO_ROOT/apps/meteor" ]; then
	bad "no apps/meteor under $REPO_ROOT"
	manual_fixes+=('Change into a Rocket.Chat worktree and run this again.')
else
	ok "$REPO_ROOT ($(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null))"
fi
echo

# Everything below needs a valid workspace.
if [ "$missing" -eq 1 ]; then
	printf 'Fix the workspace first.\n'
	exit 1
fi

# --- 2. node_modules -------------------------------------------------------------------------
echo '2. dependencies'
if [ -d "$REPO_ROOT/node_modules" ]; then
	ok 'node_modules is present'
else
	bad 'node_modules is absent'
	auto_fixes+=("cd '$REPO_ROOT' && yarn")
fi
echo

# --- 3. built packages -----------------------------------------------------------------------
# Meteor imports each workspace package through its `main`, which points at dist. An edit to a
# package source is invisible to the app until that package is built. Only changed packages can
# be stale, so ask git which ones changed instead of walking every package.
echo '3. built packages'
stale_pkgs=''
while read -r changed; do
	[ -n "$changed" ] || continue
	case "$changed" in
	packages/*) ;;
	*) continue ;;
	esac
	pkg=$(printf '%s\n' "$changed" | cut -d/ -f2)
	pkg_dir="$REPO_ROOT/packages/$pkg"
	src_file="$REPO_ROOT/$changed"
	[ -f "$src_file" ] || continue
	[ -d "$pkg_dir/dist" ] || continue
	# Newest file in dist; a source newer than that means dist is behind.
	newest_dist=$(find "$pkg_dir/dist" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1)
	src_mtime=$(stat -c '%Y' "$src_file" 2>/dev/null)
	[ -n "$newest_dist" ] && [ -n "$src_mtime" ] || continue
	if [ "${src_mtime%.*}" -gt "${newest_dist%.*}" ]; then
		case " $stale_pkgs " in
		*" $pkg "*) ;;
		*) stale_pkgs="$stale_pkgs $pkg" ;;
		esac
	fi
done <<<"$(git -C "$REPO_ROOT" status --porcelain -- packages | awk '{print $NF}')"

if [ -n "$stale_pkgs" ]; then
	bad "dist is behind the source in:$stale_pkgs"
	info 'meteor loads dist, so these edits would not appear in the recording'
	auto_fixes+=("cd '$REPO_ROOT' && yarn build")
else
	ok 'no changed package has a stale dist'
fi
echo

# --- 4. chromium -------------------------------------------------------------------------------
# The recording drives a headed Chromium on a virtual display, so the full browser is needed.
# chromium-headless-shell cannot do it: it has no window to grab.
echo '4. chromium'
PW_CACHE=${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}
if compgen -G "$PW_CACHE/chromium-[0-9]*" >/dev/null; then
	ok "$(basename "$(compgen -G "$PW_CACHE/chromium-[0-9]*" | tail -1)")"
else
	bad "no chromium-* under $PW_CACHE"
	auto_fixes+=("cd '$REPO_ROOT/apps/meteor' && yarn playwright install chromium")
fi
echo

# --- 5. capture ------------------------------------------------------------------------------
# ffmpeg grabs the X display, so it must have the x11grab device compiled in. The calibration
# grabs one frame with it too, to find where the page sits on that display.
echo '5. capture'
if command -v Xvfb >/dev/null; then
	ok "Xvfb ($(command -v Xvfb))"
else
	bad 'Xvfb is not on PATH'
	manual_fixes+=('Install Xvfb: `sudo apt install xvfb`. The recording runs the browser on a display of its own.')
fi
if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
	if ffmpeg -hide_banner -devices 2>/dev/null | grep -q x11grab; then
		ok "$(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f1-3) with x11grab"
	else
		bad 'this ffmpeg has no x11grab device'
		manual_fixes+=('Install an ffmpeg built with x11grab: `sudo apt install ffmpeg`.')
	fi
else
	bad 'ffmpeg or ffprobe is not on PATH'
	manual_fixes+=('Install ffmpeg: `sudo apt install ffmpeg` or `brew install ffmpeg`.')
fi
echo

# --- 6. audio --------------------------------------------------------------------------------
# Optional. Without it the video still records, silently. The browser plays into a null sink of
# its own and parec reads that sink's monitor, so nothing else on the machine is picked up.
echo '6. audio (optional)'
if command -v pactl >/dev/null && command -v parec >/dev/null && pactl info >/dev/null 2>&1; then
	ok "$(pactl info | sed -n 's/^Server Name: //p')"
else
	printf '  ABSENT  no PulseAudio server, or pactl/parec are missing\n'
	info 'the video records without sound; pass --no-audio to silence the warning'
	manual_fixes+=('For sound, install pulseaudio-utils (`sudo apt install pulseaudio-utils`) and make sure a PulseAudio or PipeWire server is running for your session.')
fi
echo

# --- 7. server -------------------------------------------------------------------------------
echo '7. server'
if server_env=$("$SCRIPT_DIR/find-server.sh" --env 2>/dev/null); then
	eval "$server_env"
	ok "port $SERVER_PORT, version $SERVER_VERSION, branch $SERVER_BRANCH"
	info "MONGO_URL=$SERVER_MONGO_URL"
else
	bad 'no dev server serves this worktree'
	other=$("$SCRIPT_DIR/find-server.sh" 2>/dev/null)
	if [ -n "$other" ]; then
		printf '%s\n' "$other" | sed 's/^/          /'
	fi
	manual_fixes+=('Start a server for THIS worktree. Pick a free port and its own database name, so you do not collide with another worktree: `cd apps/meteor && PORT=<free port> MONGO_DB=<own db> rc_test_mode.sh`. Wait for "SERVER RUNNING".')
fi
echo

# --- report ----------------------------------------------------------------------------------
if [ "$missing" -eq 0 ] && [ ${#manual_fixes[@]} -eq 0 ]; then
	echo 'Ready to record.'
	exit 0
fi

if [ ${#auto_fixes[@]} -gt 0 ]; then
	echo 'This script can run these fixes (pass --install):'
	for fix in "${auto_fixes[@]}"; do printf '  %s\n' "$fix"; done
	echo
fi
if [ ${#manual_fixes[@]} -gt 0 ]; then
	echo 'You must do these yourself:'
	for fix in "${manual_fixes[@]}"; do printf '  - %s\n' "$fix"; done
	echo
fi

if [ "$DO_INSTALL" -eq 0 ]; then
	[ "$missing" -eq 1 ] && exit 1
	exit 0
fi

if [ ${#auto_fixes[@]} -eq 0 ]; then
	echo 'Nothing here can be installed automatically.'
	exit 1
fi

echo 'Running the fixes now.'
for fix in "${auto_fixes[@]}"; do
	printf '\n$ %s\n' "$fix"
	if ! eval "$fix"; then
		echo "preflight.sh: the fix failed: $fix" >&2
		exit 1
	fi
done

echo
echo 'Re-checking.'
echo
exec "$0"
