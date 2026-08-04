#!/usr/bin/env bash

set -euo pipefail

REPO="https://github.com/d-gubert/dotfiles.git"
DEST="$HOME/dev/dotfiles"

# Read prompts from the terminal, not stdin: the README runs this script as
# `wget -qO- ... | bash`, so stdin is the script itself. Without </dev/tty the
# read would swallow the next script line and break parsing (case arm ')').
# read -r -p "[bootstrap] would you like to run apt-get update? [y/N] " runupdate </dev/tty

OS=$(uname)

if [[ "$OS" == "Darwin" ]]; then
	# make and git both ship with the Xcode Command Line Tools. Note that
	# /usr/bin/make exists as a stub even when the tools are absent, so
	# `command -v make` always succeeds and can't be used to detect them —
	# ask xcode-select instead.
	if xcode-select -p >/dev/null 2>&1; then
		echo "[bootstrap] Xcode Command Line Tools already installed"
	else
		echo "[bootstrap] installing Xcode Command Line Tools..."
		xcode-select --install 2>/dev/null || true

		echo "[bootstrap] waiting for the installer to finish (up to 10 minutes)..."
		i=0
		until xcode-select -p >/dev/null 2>&1; do
			if [ "$i" -ge 120 ]; then
				echo "[bootstrap] timed out waiting for the Command Line Tools." >&2
				echo "[bootstrap] finish the installer, then re-run this script." >&2
				exit 1
			fi
			sleep 5
			# Not ((i++)): it returns the pre-increment value, so the first
			# iteration would exit status 1 and `set -e` would kill the script.
			i=$((i + 1))
		done
		echo "[bootstrap] Xcode Command Line Tools installed"
	fi
else
	sudo apt-get -y update
	sudo apt-get -y install git build-essential
fi

if [ -d "$DEST" ]; then
	echo "[bootstrap] $DEST already exists, pulling latest..."
	git -C "$DEST" pull
else
	echo "[bootstrap] cloning $REPO to $DEST..."
	mkdir -p "$(dirname "$DEST")"
	git clone "$REPO" "$DEST"
fi

echo "[bootstrap] running make all..."
make -C "$DEST" all
