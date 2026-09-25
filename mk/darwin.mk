# macOS. Included by the main Makefile as mk/$(OS_FAMILY).mk.
#
# Every family file provides the same names -- BREW_PREFIX, STOW_OS_PKG and
# EXTRA_ESSENTIAL -- plus the install targets whose recipe differs by OS,
# whether it defines them itself or picks them up from mk/linux.mk. Keep the
# three families in sync when you add one.

include mk/brew.mk
include mk/scripts.mk

BREW_PREFIX := /opt/homebrew
STOW_OS_PKG := mac

# aerospace -- a tiling window manager, macOS only
# MAC_ESSENTIAL_TOOLS -- plain brew packages that only macOS installs
# macos-defaults -- the keyboard shortcuts from System Settings
EXTRA_ESSENTIAL := install-aerospace install-mac-essential macos-defaults

# maccy -- a clipboard manager (a cask; brew finds it without --cask)
MAC_ESSENTIAL_TOOLS := maccy

.PHONY: install-mac-essential
install-mac-essential: homebrew
	@$(call pkg_add,$(MAC_ESSENTIAL_TOOLS))

.PHONY: install-spotatui
install-spotatui: homebrew
	@if command -v spotatui >/dev/null 2>&1; then echo "[spotatui] already installed"; else \
		echo "[spotatui] installing via homebrew..."; \
		$(BREW) tap LargeModGames/spotatui
		$(BREW_INSTALL) spotatui; \
	fi

.PHONY: pre-tmux
# Install via homebrew in MacOS
pre-tmux: homebrew
	@if command -v tmux >/dev/null 2>&1; then echo "[tmux] already installed"; else \
		echo "[tmux] installing via brew..."; \
		$(BREW_INSTALL) tmux; \
	fi

.PHONY: install-enpass
install-enpass: homebrew
	@if $(BREW) info enpass | grep -q Installed; then echo "[enpass] already installed"; else \
		echo "[enpass] installing via brew..."; \
		$(BREW_INSTALL) --cask enpass; \
	fi

.PHONY: install-alacritty
install-alacritty: homebrew
	@if command -v alacritty >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[alacritty] installing via brew..."; \
		$(BREW_INSTALL) --cask alacritty; \
	fi

.PHONY: install-wezterm
install-wezterm: homebrew
	@if command -v wezterm >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[wezterm] installing via brew..."; \
		$(BREW_INSTALL) --cask wezterm; \
	fi

.PHONY: install-kanata
# scripts/kanata-macos.sh holds the steps: the driver, the launchd daemons and
# the keyboard type.
install-kanata: homebrew stow
	@BREW=$(BREW) scripts/kanata-macos.sh

# The cask lives in the vendor tap, not in homebrew/cask.
.PHONY: install-aerospace
install-aerospace: homebrew
	@if $(BREW) list --cask aerospace >/dev/null 2>&1; then echo "[aerospace] already installed"; else \
		echo "[aerospace] installing via brew..."; \
		$(BREW_INSTALL) --cask nikitabobko/tap/aerospace; \
	fi

# scripts/macos-defaults.sh holds the keyboard shortcuts from System Settings.
.PHONY: macos-defaults
macos-defaults:
	@scripts/macos-defaults.sh

# macOS ships curl, so there is nothing to install.
.PHONY: install-curl
install-curl:
	@echo "[curl] already installed"
