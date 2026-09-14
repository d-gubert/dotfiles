#!/usr/bin/env zsh

# Switch between the two built-in Hyprland layouts.
# Bound to SUPER + ALT + L in ~/.config/hypr/bindings.conf.
#
# The port of Omarchy's omarchy-hyprland-workspace-layout-toggle. Omarchy
# switches the layout of one workspace. Plain Hyprland keeps general:layout for
# the whole session, so this switches everywhere.
#
# hyprctl keyword writes a runtime value, not the config file, so a reload
# (SUPER + SHIFT + C) puts the layout back to the one in looknfeel.conf.

if [[ "$(hyprctl getoption general:layout -j | jq -r '.str')" == "dwindle" ]]; then
	hyprctl keyword general:layout master
	notify-send "Layout: master"
else
	hyprctl keyword general:layout dwindle
	notify-send "Layout: dwindle"
fi
