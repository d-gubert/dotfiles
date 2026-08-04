# Linux-specific shell settings. Sourced by common/.zshrc.
# The macOS counterpart lives in mac/.zshrc.os — keep the two in sync.

# Used by mypr() and anything else that opens a URL or copies to the clipboard.
export OPEN_CMD="xdg-open"
export CLIP_CMD="xclip -selection clipboard"

# Playwright ships no browser builds for Ubuntu 26.04+. Its platform detection
# falls through to a literal "ubuntu26.04-x64" key that matches nothing in the
# download table, so `playwright install` dies with "does not support chromium".
# Pin to the 24.04 fallback build, which runs fine (no missing shared libs).
#
# The arch suffix is MANDATORY: this value replaces the entire platform string
# rather than just the version, so a bare "ubuntu24.04" also matches nothing.
#
# Drop this once Playwright ships native 26.04 builds — until then it would
# keep forcing the older build. Guarded so 24.04 boxes stay on native builds.
if [[ -r /etc/os-release ]]; then
	if [[ "${$(. /etc/os-release && echo $ID)}" == "ubuntu" ]] &&
		(( ${$(. /etc/os-release && echo ${VERSION_ID%%.*})} >= 26 )); then
		export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE="ubuntu24.04-x64"
	fi
fi
