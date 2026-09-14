#!/usr/bin/env zsh

# List every keybinding in rofi, read only.
# Bound to SUPER + SHIFT + K in ~/.config/hypr/bindings.conf.
#
# The port of Omarchy's omarchy-menu-keybindings. Omarchy reads the
# descriptions its own config layer holds; this reads the ones Hyprland holds,
# which is why every binding in bindings.conf uses bindd instead of bind. A
# binding with no description never appears here.
#
# hyprctl reports the modifiers as a bit mask, so the mask is decoded below:
# SHIFT 1, CAPS 2, CTRL 4, ALT 8, SUPER 64.

hyprctl binds -j | jq -r '
	def bit($m; $b): (($m / $b) | floor) % 2 == 1;
	def mods($m): [
		(if bit($m; 64) then "SUPER" else empty end),
		(if bit($m; 4)  then "CTRL"  else empty end),
		(if bit($m; 8)  then "ALT"   else empty end),
		(if bit($m; 1)  then "SHIFT" else empty end)
	] | join(" + ");

	.[]
	| select(.description != "")
	| [ (if .submap == "" then "" else "[" + .submap + "] " end)
	    + (if .modmask == 0 then "" else mods(.modmask) + " + " end)
	    + (.key | ascii_upcase),
	    .description ]
	| @tsv
' | column -t -s $'\t' | rofi -dmenu -i -no-custom -p "Keybindings" >/dev/null
