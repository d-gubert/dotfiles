#!/usr/bin/env bash
#
# Check every prerequisite a recording needs, in one pass, and say exactly what is missing.
#
# Checks:
#   1. platform        - which file under platform/ fits this host (see platform.sh)
#   2. workspace       - this is a git checkout that holds apps/meteor
#   3. node_modules    - dependencies are installed
#   4. built packages  - no changed package source is newer than its dist (meteor loads dist)
#   5. chromium        - the playwright browser the chosen strategy drives
#   6. capture         - which strategy will record, and what the better one would need
#   7. audio           - whatever the platform needs to record what the app plays (optional)
#   8. server          - a running Rocket.Chat dev server to record against
#
# A host with no virtual display still passes: `record.sh` falls back to Playwright's own recorder.
# What that host lacks is reported as ABSENT with an optional fix, not as a failure.
#
# Usage:
#   preflight.sh              # report only; exit 0 when ready, 1 when something is missing
#   preflight.sh --install    # also install what this script can install, then re-check
#
# Ask the user before you pass --install. Two of the fixes are slow (`yarn build`, a browser
# download). The dev server is never one of the fixes: this script reports it as missing and stops
# there.
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
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform.sh"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')

missing=0
# Fixes this script can run itself, one shell command per line.
auto_fixes=()
# Fixes only the user can make.
manual_fixes=()
# Fixes that buy a better recording but are not needed to record at all.
optional_fixes=()

ok() { printf '  OK      %s\n' "$1"; }
bad() {
	printf '  MISSING %s\n' "$1"
	missing=1
}
info() { printf '          %s\n' "$1"; }

# Turn the `STATUS|label|info|fix` rows of a platform check into report lines. ABSENT marks an
# optional feature that is unavailable, and never fails the preflight.
#
# In `optional` mode a MISSING row reads as ABSENT and its fix goes to the optional list. That is
# what the capture check uses once it has settled on the Playwright fallback: the missing tools no
# longer block a recording, they only cost quality.
render_rows() {
	local mode=${1:-required} status label note fix
	while IFS='|' read -r status label note fix; do
		case "$status" in
		OK) ok "$label" ;;
		MISSING)
			if [ "$mode" = optional ]; then
				printf '  ABSENT  %s\n' "$label"
			else
				bad "$label"
			fi
			;;
		ABSENT) printf '  ABSENT  %s\n' "$label" ;;
		*) continue ;;
		esac
		[ -n "$note" ] && info "$note"
		if [ -n "$fix" ]; then
			if [ "$mode" = optional ]; then optional_fixes+=("$fix"); else manual_fixes+=("$fix"); fi
		fi
	done
	return 0
}

# Later checks assume the platform and the workspace, so a failure there stops the run. Print what
# the user has to do before leaving; the report at the end never runs.
stop_here() {
	printf '\n%s\n' "$1"
	if [ ${#manual_fixes[@]} -gt 0 ]; then
		for fix in "${manual_fixes[@]}"; do printf '  - %s\n' "$fix"; done
	fi
	exit 1
}

echo 'Recording preflight'
echo

# --- 1. platform -----------------------------------------------------------------------------
# platform.sh picks the file under platform/ that fits this host. Everything the display, the
# capture, the audio and the server lookup do differently per system lives behind it. `portable`
# fits every host and knows host facts only, so this check fails on nothing but a host without ps.
echo '1. platform'
if [ -n "$PLATFORM_ID" ]; then
	ok "$PLATFORM_NAME ($PLATFORM_ID)"
	[ "$PLATFORM_CAPTURE" = native ] || info 'host facts only; section 6 says how the recording will be captured'
else
	bad "no platform file fits this host: $PLATFORM_REASON"
	manual_fixes+=('Add a file for this host under scripts/platform/. platform.sh documents what such a file must implement.')
fi
echo

[ "$missing" -eq 0 ] || stop_here 'This skill cannot run here:'

# Which strategy will record. Section 6 reports it; section 5 needs it first, because the two
# strategies drive different browser builds.
CAPTURE_STRATEGY=playwright
platform_capture_ready && CAPTURE_STRATEGY=native

# --- 2. workspace ----------------------------------------------------------------------------
echo '2. workspace'
if [ -z "$REPO_ROOT" ]; then
	bad 'not inside a git repository'
	manual_fixes+=('Change into a Rocket.Chat checkout and run this again.')
elif [ ! -d "$REPO_ROOT/apps/meteor" ]; then
	bad "no apps/meteor under $REPO_ROOT"
	manual_fixes+=('Change into a Rocket.Chat checkout and run this again.')
else
	ok "$REPO_ROOT ($(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null))"
fi
echo

# Everything below needs a valid workspace.
[ "$missing" -eq 0 ] || stop_here 'Fix the workspace first:'

# --- 3. node_modules -------------------------------------------------------------------------
echo '3. dependencies'
if [ -d "$REPO_ROOT/node_modules" ]; then
	ok 'node_modules is present'
else
	bad 'node_modules is absent'
	auto_fixes+=("cd '$REPO_ROOT' && yarn")
fi
echo

# --- 4. built packages -----------------------------------------------------------------------
# Meteor imports each workspace package through its `main`, which points at dist. An edit to a
# package source is invisible to the app until that package is built. Only changed packages can
# be stale, so ask git which ones changed instead of walking every package.
echo '4. built packages'
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

# --- 5. chromium -------------------------------------------------------------------------------
# Each strategy needs a different build, and `yarn playwright install chromium` fetches both.
#   native      the full browser. It runs headed on the virtual display, and chromium-headless-shell
#               cannot stand in: it has no window to grab.
#   playwright  the headless shell. It draws no browser chrome, so its surface is the viewport and
#               the video needs no padding. The full browser draws chrome even headless, and
#               Playwright then pads the video with a grey band.
echo '5. chromium'
PW_CACHE=${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}
if [ "$CAPTURE_STRATEGY" = native ]; then
	pw_browser_glob="$PW_CACHE/chromium-[0-9]*"
	pw_browser_label='chromium'
else
	pw_browser_glob="$PW_CACHE/chromium_headless_shell-[0-9]*"
	pw_browser_label='chromium_headless_shell'
fi
if compgen -G "$pw_browser_glob" >/dev/null; then
	ok "$(basename "$(compgen -G "$pw_browser_glob" | tail -1)")"
else
	bad "no $pw_browser_label-* under $PW_CACHE"
	auto_fixes+=("cd '$REPO_ROOT/apps/meteor' && yarn playwright install chromium")
fi
echo

# --- 6. capture ------------------------------------------------------------------------------
# Two strategies, and the host decides. `native` grabs a virtual display with ffmpeg, at a constant
# frame rate and with the audio the app plays. `playwright` is the fallback for a host that cannot:
# the browser records itself, worse but without a single extra tool.
echo '6. capture'
if [ "$CAPTURE_STRATEGY" = native ]; then
	ok 'strategy: native - ffmpeg grabs a virtual display, full frame rate, sound included'
	render_rows required < <(platform_check_capture)
else
	printf '  ABSENT  %s\n' 'strategy: playwright - the browser records itself'
	info 'no audio, about 25 fps, and a frame only when the page changes'
	# What native would have needed. None of it blocks a recording here, so none of it fails.
	render_rows optional < <(platform_check_capture)
	# ffmpeg is optional on this path: it turns the webm into an mp4 and cuts the check frames.
	if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
		ok "$(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f1-3) - the webm becomes an mp4"
	else
		printf '  ABSENT  %s\n' 'no ffmpeg on PATH'
		info 'record.sh delivers the raw webm and cuts no check frames'
		optional_fixes+=('Install ffmpeg to get an mp4 and check frames: `sudo apt install ffmpeg` or `brew install ffmpeg`.')
	fi
fi
echo

# --- 7. audio --------------------------------------------------------------------------------
# Optional. Without it the video still records, silently.
echo '7. audio (optional)'
if [ "$CAPTURE_STRATEGY" = native ]; then
	render_rows required < <(platform_check_audio)
else
	printf '  ABSENT  %s\n' "Playwright's recorder writes no audio track"
	info 'pass --no-audio to record.sh to silence the warning'
fi
echo

# --- 8. server -------------------------------------------------------------------------------
echo '8. server'
if server_env=$("$SCRIPT_DIR/find-server.sh" --env 2>/dev/null); then
	eval "$server_env"
	ok "port $SERVER_PORT, version $SERVER_VERSION, branch $SERVER_BRANCH"
	info "MONGO_URL=$SERVER_MONGO_URL"
elif others=$("$SCRIPT_DIR/find-server.sh" 2>/dev/null); then
	# Servers run, but more than one, and none of them is the obvious choice.
	bad 'several dev servers run and none is clearly the one to record against'
	printf '%s\n' "$others" | sed 's/^/          /'
	manual_fixes+=('Say which server to use: pass `--port <port>` to record.sh and rc-api.sh.')
else
	bad 'no dev server to record against'
	manual_fixes+=('A Rocket.Chat dev server must already run, and answer, before you record. This skill drives a server; it does not start one.')
fi
echo

# --- report ----------------------------------------------------------------------------------
if [ "$missing" -eq 0 ] && [ ${#manual_fixes[@]} -eq 0 ] && [ ${#optional_fixes[@]} -eq 0 ]; then
	echo "Ready to record, the $CAPTURE_STRATEGY way."
	exit 0
fi
if [ "$missing" -eq 0 ] && [ ${#manual_fixes[@]} -eq 0 ]; then
	echo "Ready to record, the $CAPTURE_STRATEGY way."
	echo
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
if [ ${#optional_fixes[@]} -gt 0 ]; then
	echo 'Optional - these buy a better recording, and nothing here blocks one:'
	for fix in "${optional_fixes[@]}"; do printf '  - %s\n' "$fix"; done
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
