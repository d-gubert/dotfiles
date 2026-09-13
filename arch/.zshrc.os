# Arch-specific shell settings. Sourced by common/.zshrc.
# The Ubuntu counterpart lives in ubuntu/.zshrc.os and the macOS one in
# mac/.zshrc.os — keep the three in sync.

# Used by mypr() and anything else that opens a URL or copies to the clipboard.
export OPEN_CMD="xdg-open"

# Omarchy runs Hyprland, so there is no X11 selection for xclip to talk to and
# the Ubuntu package's `xclip -selection clipboard` would fail silently. wl-copy
# reads stdin and needs no flag to target the regular clipboard, so CLIP_CMD
# stays a bare command like it is on the other two platforms.
export CLIP_CMD="wl-copy"

# No Homebrew here. Everything the Makefile installs through brew on Ubuntu and
# macOS comes from pacman or the AUR on Arch, which puts it in /usr/bin — so
# there is no shellenv to eval and nothing to add to PATH.

# mise stands in for volta as the toolchain manager (node, gh, claude, codex).
# Omarchy wires it into bash in two places: default/bash/env-bootstrap appends
# the shims so login and non-interactive shells resolve the tools, and
# default/bash/init runs `mise activate` for interactive ones. Do both here so a
# zsh login shell behaves the same as the bash one Omarchy ships.
#
# common/.zshrc still prepends $VOLTA_HOME/bin further down. That directory does
# not exist on an Arch box, and a missing PATH entry is a no-op, so the two
# coexist without volta shadowing mise.
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
	case ":$PATH:" in
	*":$HOME/.local/share/mise/shims:"*) ;;
	*) export PATH="${PATH:+$PATH:}$HOME/.local/share/mise/shims" ;;
	esac
fi

if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate zsh)"
fi
