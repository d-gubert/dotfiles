#!/usr/bin/env bash
# Install kanata on macOS and start it at boot. `make install-kanata` runs this
# script after homebrew and stow. Linux does the same work in mk/systemd.mk.
#
# Every step checks the current state first, so you can run the script again.
# Some steps use sudo, so expect a password prompt.
#
# Usage:
#   scripts/kanata-macos.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW="${BREW:-/opt/homebrew/bin/brew}"

# kanata drives the keyboard through Karabiner's VirtualHIDDevice driver. Each
# kanata release supports one major version of the driver, and its release
# notes name it. Karabiner-Elements bundles a newer driver whose socket kanata
# cannot find ("connect_failed asio.system:2"), so install the standalone pkg
# and not the cask. Bump VHID_VERSION together with kanata.
VHID_VERSION=6.2.0
VHID_PKG="Karabiner-DriverKit-VirtualHIDDevice-$VHID_VERSION.pkg"
VHID_URL="https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v$VHID_VERSION/$VHID_PKG"
VHID_DAEMON="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app"
VHID_MANAGER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"

# Two root daemons start at boot: the VirtualHIDDevice daemon and kanata. See
# the comments in the plists for why each one runs as root.
DAEMONS=(local.dotfiles.karabiner-vhiddaemon local.dotfiles.kanata)

# macOS can take the Karabiner virtual keyboard for an ISO keyboard (type 41),
# and then the key below Esc types § and ± in place of ` and ~. The key of the
# entry is <product>-<vendor>-33: 0x27db and 0x16c0 are the IDs of the virtual
# keyboard. Type 40 is ANSI.
VHID_KBD=10203-5824-33

log() { echo "[kanata] $*"; }

install_kanata() {
	if command -v kanata >/dev/null 2>&1; then
		log "already installed"
	else
		log "installing via brew..."
		"$BREW" install --no-ask kanata
	fi
}

remove_karabiner_elements() {
	if "$BREW" list --cask karabiner-elements >/dev/null 2>&1; then
		log "removing Karabiner-Elements, its driver is too new for kanata..."
		"$BREW" uninstall --cask karabiner-elements
	fi
}

# The driver is a system extension, so macOS requires it to be approved by
# hand. The manager requests the activation and waits for the approval.
install_driver() {
	local installed tmp
	installed="$(defaults read "$VHID_DAEMON/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)"
	if [ "$installed" = "$VHID_VERSION" ]; then
		log "VirtualHIDDevice driver $VHID_VERSION already installed"
	else
		log "installing the VirtualHIDDevice driver $VHID_VERSION..."
		tmp="$(mktemp -d)"
		curl -fsSL -o "$tmp/$VHID_PKG" "$VHID_URL"
		sudo installer -pkg "$tmp/$VHID_PKG" -target /
		rm -rf "$tmp"
		log "requesting the VirtualHIDDevice driver activation..."
		"$VHID_MANAGER" activate
		sudo launchctl kickstart -k system/local.dotfiles.karabiner-vhiddaemon 2>/dev/null || true
		return
	fi
	if systemextensionsctl list 2>/dev/null | grep -q 'org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.*activated enabled'; then
		log "VirtualHIDDevice driver already active"
	else
		log "requesting the VirtualHIDDevice driver activation..."
		"$VHID_MANAGER" activate
	fi
}

# A `sudo brew services start kanata` job would run a second kanata against the
# same keyboard, so stop it.
stop_brew_service() {
	if [ -f /Library/LaunchDaemons/sh.brew.kanata.plist ]; then
		log "stopping the brew services job..."
		sudo "$BREW" services stop kanata
	fi
}

# A root daemon cannot be a symlink, so copy each plist. launchd does not
# expand ~ or $HOME, so replace @HOME@ on the way.
install_daemons() {
	local d src dst tmp
	for d in "${DAEMONS[@]}"; do
		src="$REPO_DIR/system/Library/LaunchDaemons/$d.plist"
		dst="/Library/LaunchDaemons/$d.plist"
		tmp="$(mktemp)"
		sed "s|@HOME@|$HOME|g" "$src" >"$tmp"
		if cmp -s "$tmp" "$dst" && sudo launchctl print "system/$d" >/dev/null 2>&1; then
			log "$d already loaded"
		else
			log "installing and loading $d..."
			sudo launchctl bootout "system/$d" 2>/dev/null || true
			sudo install -m 0644 -o root -g wheel "$tmp" "$dst"
			sudo launchctl bootstrap system "$dst"
		fi
		rm -f "$tmp"
	done
}

set_ansi_layout() {
	local current
	current="$(defaults read /Library/Preferences/com.apple.keyboardtype keyboardtype 2>/dev/null |
		grep "\"$VHID_KBD\"" | tr -dc '0-9' | tail -c 2 || true)"
	if [ "$current" = "40" ]; then
		log "virtual keyboard already set to ANSI"
	else
		log "setting the virtual keyboard type to ANSI..."
		sudo defaults write /Library/Preferences/com.apple.keyboardtype keyboardtype -dict-add "$VHID_KBD" -int 40
	fi
}

main() {
	install_kanata
	remove_karabiner_elements
	install_driver
	stop_brew_service
	install_daemons
	set_ansi_layout

	log "NOTE: two approvals stay manual. Allow the driver under System"
	log "      Settings > General > Login Items & Extensions > Driver"
	log "      Extensions. Add $(readlink -f "$(command -v kanata)")"
	log "      under Privacy & Security > Input Monitoring."
}

main "$@"
