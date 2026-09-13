#!/usr/bin/env zsh

# Select an area, save it, and put it on the clipboard.
# Bound to Print in ~/.config/hypr/bindings.conf.
#
# The Wayland port of ~/.config/i3/scripts/printscreen.sh: slurp replaces the
# -s of maim, grim takes the picture, and wl-copy replaces xclip. grim leaves
# the cursor out unless -c is given, which is what maim -u does.

mkdir -p ~/Pictures/Screenshots/

fname=~/Pictures/Screenshots/Screenshot-$(date -Iseconds | cut -d'+' -f1).png

# slurp exits non-zero when the selection is cancelled. Do nothing then.
geometry=$(slurp) || exit 1

grim -g "$geometry" "$fname" || exit 1

wl-copy -t image/png < "$fname"

notify-send "Screenshot copied" "$fname"
