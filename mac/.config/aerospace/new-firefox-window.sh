#!/bin/bash
# Firefox activates its existing window before it opens a new one, and AeroSpace
# follows that focus to the workspace of the existing window. The new window
# lands there too, so move it back to the workspace we started from.

PATH=/opt/homebrew/bin:$PATH

list_windows() {
	aerospace list-windows --monitor all --app-bundle-id org.mozilla.firefox --format '%{window-id}' | sort
}

workspace=$(aerospace list-workspaces --focused)
before=$(list_windows)

# When Firefox is not running, this process becomes Firefox, so do not wait for it.
/Applications/Firefox.app/Contents/MacOS/firefox --new-window >/dev/null 2>&1 &

for _ in $(seq 100); do
	window=$(comm -13 <(echo "$before") <(list_windows) | head -1)
	[ -n "$window" ] && break
	sleep 0.1
done

[ -n "$window" ] || exit 1

aerospace move-node-to-workspace --focus-follows-window --window-id "$window" "$workspace"
