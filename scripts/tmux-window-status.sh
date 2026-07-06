#!/usr/bin/env zsh
# Decorate the current tmux window name with a status_glyph
#
# Called by Claude Code hooks (see ../hooks/hooks.json) with a state argument.
#
# Sets the per-window @status_glyph user option, which ~/.tmux.conf splices
# into the catppuccin window label (see @catppuccin_window_text there).
set -eu

# Not inside tmux (background/remote/plain terminal): nothing to decorate.
[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

case "${1:-clear}" in
  attention) glyph="🔔 " ;;  # Notification: Claude needs permission / attention
  busy-done) glyph="⬤  "  ;;  # Stop: Claude finished its turn, your move
  clear | *) glyph=""    ;;
esac

# Target the window that owns this pane; leave other windows untouched.
tmux set-option -w -t "$TMUX_PANE" @status_glyph "$glyph"
tmux refresh-client -S 2>/dev/null || true

[ -n "$glyph" ] && tmux set-hook -t "$TMUX_PANE" pane-focus-in "run-shell '${0:A} clear; tmux set-hook -u -t $TMUX_PANE pane-focus-in'"
