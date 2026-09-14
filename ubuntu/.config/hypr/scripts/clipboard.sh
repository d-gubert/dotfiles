#!/usr/bin/env zsh

# Pick an entry from the clipboard history and copy it back.
# Bound to SUPER + V in ~/.config/hypr/bindings.conf.
#
# The Wayland port of the i3 clipmenu binding. clipmenu reads the X11
# selection, so it cannot see a Wayland clipboard. cliphist replaces it: the
# two wl-paste watchers in autostart.conf write every copy to the history, and
# this script reads it back.
#
# cliphist list prints "id<TAB>preview". rofi -display-columns 2 hides the id
# column and still returns the whole row, which is what cliphist decode needs.
#
# CTRL + J and CTRL + K move down and up the list. ENTER or CTRL + M copies
# the entry, CTRL + D removes it, ESCAPE or CTRL + C cancels.
#
# rofi refuses to start when a key is bound twice, and it holds the keyboard
# while it shows that error, so every key below is taken from its default
# action first. The defaults that move are:
#
#   kb-secondary-copy     Control+c   freed, no use in a picker
#   kb-remove-to-eol      Control+k   freed, no use in a picker
#   kb-remove-char-forward
#                         Control+d   keeps Delete
#   kb-accept-entry       Control+j   keeps Control+m, Return and KP_Enter
#
# The arrow keys and the CTRL + N and CTRL + P defaults stay. Escape stays a
# cancel key: it is the way out if this menu ever fails again.

pick=$(cliphist list | rofi -dmenu -i -p "Clipboard" \
	-display-columns 2 \
	-kb-secondary-copy "" \
	-kb-remove-to-eol "" \
	-kb-cancel "Escape,Control+c" \
	-kb-remove-char-forward "Delete" \
	-kb-custom-1 "Control+d" \
	-kb-row-down "Down,Control+n,Control+j" \
	-kb-row-up "Up,Control+p,Control+k" \
	-kb-accept-entry "Return,KP_Enter,Control+m")

# Do not name this variable "status". zsh keeps $status as a read-only synonym
# for $?, and the assignment stops the script before either branch runs.
# rofi exits 0 on ENTER and 10 on the first custom key, which is CTRL + D.
rc=$?

case $rc in
	0)  print -r -- "$pick" | cliphist decode | wl-copy ;;
	10) print -r -- "$pick" | cliphist delete ;;
esac
