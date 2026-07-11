#!/usr/bin/env bash

set -euo pipefail

REPO="https://github.com/d-gubert/dotfiles.git"
DEST="$HOME/dev/dotfiles"

# Read prompts from the terminal, not stdin: the README runs this script as
# `wget -qO- ... | bash`, so stdin is the script itself. Without </dev/tty the
# read would swallow the next script line and break parsing (case arm ')').
# read -r -p "[bootstrap] would you like to run apt-get update? [y/N] " runupdate </dev/tty

sudo apt-get -y update
sudo apt-get -y install git build-essential

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
