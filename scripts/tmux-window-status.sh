#!/usr/bin/env zsh
# Decorate the current tmux window name with a status_glyph
#
# Called by Claude Code hooks (see ../hooks/hooks.json) with a state argument.
#
# Sets the per-window @status_glyph user option, which ~/.tmux.conf splices
# into the catppuccin window label (see @catppuccin_window_text there).
set -eu

source $DOTFILES_SCRIPTS/lib/tmux-helpers.sh

# Not inside tmux (background/remote/plain terminal): nothing to decorate.
[ -n "${TMUX:-}" ] || exit 0

action="$1"
noop_on_active_pane=false

if [ "${action}" = "pane-focus-in" ]; then
	TMUX_PANE=$2
	# read -r currPaneId < <(tj -r '.pane.id')
elif [ "${2:-}" = "--ignore-on-active-pane" ]; then
	noop_on_active_pane=true
fi

if $noop_on_active_pane && [ "$TMUX_PANE" = "$(tj -r '.pane.id')" ]; then
	return 0
fi

glyph=""

case "${action:-clear}" in
	attention) glyph="🔔 " ;;      # Notification: Claude needs permission / attention
	busy-done) glyph="⬤  "  ;;     # Stop: Claude finished its turn, your move
	pane-focus-in) TMUX_PANE=$2 ;; # If we've been called from the hook, second arg is the pane id
esac

#Target the window that owns this pane; leave other windows untouched.
tmux set-option -w -t "$TMUX_PANE" @status_glyph "$glyph"
tmux refresh-client -S 2>/dev/null

if [ -n "$glyph" ]; then
	printf '\a'
fi
