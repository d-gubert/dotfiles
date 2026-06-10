#!/usr/bin/env bash

set -euo pipefail

REPO="https://github.com/d-gubert/dotfiles.git"
DEST="$HOME/dev/dotfiles"

read -r -p "[bootstrap] would you like to run apt-get update? [y/N]" runupdate
case "$runupdate" in
	[yY])
		sudo apt-get update -y
		;;
esac

if ! command -v git >/dev/null 2>&1; then
	echo "[bootstrap] git is not installed."
	read -r -p "Install git via apt? [y/N] " answer
	case "$answer" in
		[yY])
			sudo apt-get install -y git
			;;
		*)
			echo "[bootstrap] git is required. Aborting."
			exit 1
			;;
	esac
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
