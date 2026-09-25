#!/usr/bin/env bash
# Apply the macOS keyboard shortcuts that System Settings -> Keyboard ->
# Keyboard Shortcuts stores. `make macos-defaults` runs this script.
#
# macOS keeps these shortcuts in com.apple.symbolichotkeys, under
# AppleSymbolicHotKeys. Each shortcut has a numeric ID that Apple does not
# document, and a macOS update can change the IDs. The script writes only the
# IDs listed below and keeps every other ID as it is.
#
# To see the current state after you change a shortcut in System Settings:
#   defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys
#
# Usage:
#   scripts/macos-defaults.sh
set -euo pipefail

DOMAIN=com.apple.symbolichotkeys

# hotkey ID ENABLED [CHAR KEYCODE MODIFIERS]
#
# CHAR is the ASCII code of the key, or 65535 when the key has no character
# (arrows, F-keys). KEYCODE is the virtual key code. MODIFIERS is a sum of:
#   shift 131072, ctrl 262144, opt 524288, cmd 1048576, fn 8388608
# macOS adds the fn flag to the arrow keys and the F-keys on its own.
# 65535 65535 0 means "no key assigned". Without the three values, macOS uses
# the default key for that ID.
hotkey() {
	local id=$1 enabled=$2 value=""
	local flag="<false/>"
	[ "$enabled" = 1 ] && flag="<true/>"
	if [ $# -eq 5 ]; then
		value="<key>value</key><dict><key>type</key><string>standard</string>"
		value+="<key>parameters</key><array>"
		value+="<integer>$3</integer><integer>$4</integer><integer>$5</integer>"
		value+="</array></dict>"
	fi
	defaults write "$DOMAIN" AppleSymbolicHotKeys -dict-add "$id" \
		"<dict><key>enabled</key>$flag$value</dict>"
}

# Accessibility: zoom, contrast and invert colors
for id in 15 16 17 18 19 20 21 22 23 24 25 26; do
	hotkey "$id" 0
done

# Mission Control. AeroSpace handles workspaces, so the ctrl+arrow keys are off.
hotkey 32 0 65535 126 8650752 # Mission Control: ctrl+up
hotkey 33 0 65535 125 8650752 # Application windows: ctrl+down
hotkey 34 1 65535 126 8781824 # Mission Control, second key: ctrl+shift+up
hotkey 36 0 65535 103 8388608 # Show Desktop: F11
hotkey 79 0 65535 123 8650752 # Move left a space: ctrl+left
hotkey 80 1                   # Move left a space, second key: default
hotkey 81 0 65535 124 8650752 # Move right a space: ctrl+right
hotkey 82 1 65535 124 8781824 # Move right a space, second key: ctrl+shift+right
hotkey 118 0 65535 18 262144  # Switch to Desktop 1: ctrl+1
hotkey 119 0 65535 19 262144  # Switch to Desktop 2: ctrl+2

# Dock
hotkey 52 0 100 2 1572864 # Turn Dock hiding on/off: cmd+opt+d

# Input sources
hotkey 60 1 32 49 262144 # Select the previous input source: ctrl+space
hotkey 61 1 32 49 786432 # Select next source in Input menu: ctrl+opt+space

# Quick Note
hotkey 190 0 113 12 8388608 # fn+q

# Window tiling (macOS 15 and later). AeroSpace does the tiling.
hotkey 237 0 102 3 8650752      # Fill: fn+ctrl+f
hotkey 238 0 99 8 8650752       # Center: fn+ctrl+c
hotkey 239 0 114 15 8650752     # Return to previous size: fn+ctrl+r
hotkey 240 0 65535 123 8650752  # Tile left: fn+ctrl+left
hotkey 241 0 65535 124 8650752  # Tile right: fn+ctrl+right
hotkey 242 0 65535 126 8650752  # Tile top: fn+ctrl+up
hotkey 243 0 65535 125 8650752  # Tile bottom: fn+ctrl+down
hotkey 248 0 65535 123 8781824  # Arrange left and right: fn+ctrl+shift+left
hotkey 249 0 65535 124 8781824  # Arrange right and left: fn+ctrl+shift+right
hotkey 250 0 65535 126 8781824  # Arrange top and bottom: fn+ctrl+shift+up
hotkey 251 0 65535 125 8781824  # Arrange bottom and top: fn+ctrl+shift+down
for id in 244 245 246 247 256 257 258; do
	hotkey "$id" 0 65535 65535 0 # Tile quarters and more: no key
done

# Shortcuts with no key assigned, off
for id in 164 175 222 235; do
	hotkey "$id" 0 65535 65535 0
done

# Other shortcuts, off
hotkey 233 0 109 46 1048576  # cmd+m
hotkey 260 0 65535 53 1048576 # cmd+esc

# Load the new values without a logout.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

echo "[macos-defaults] keyboard shortcuts applied"
