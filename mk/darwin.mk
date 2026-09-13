# macOS. Included by the main Makefile as mk/$(OS_FAMILY).mk.
#
# Every family file provides the same names -- BREW_PREFIX, STOW_OS_PKG and
# EXTRA_ESSENTIAL -- plus the install targets whose recipe differs by OS,
# whether it defines them itself or picks them up from mk/linux.mk. Keep the
# three families in sync when you add one.

include mk/brew.mk

BREW_PREFIX := /opt/homebrew
STOW_OS_PKG := mac

# base-essential is the whole of `essential` on macOS.
EXTRA_ESSENTIAL :=

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
# On macOS kanata drives the keyboard through Karabiner's VirtualHIDDevice
# driver, which ships with Karabiner-Elements. The driver is a system extension,
# so macOS requires it to be approved by hand — brew can install it but cannot
# activate it.
install-kanata: homebrew
	@if command -v kanata >/dev/null 2>&1; then echo "[kanata] already installed"; else \
		echo "[kanata] installing via brew..."; \
		$(BREW_INSTALL) kanata; \
	fi
	@if [ -d "/Applications/Karabiner-Elements.app" ]; then \
		echo "[kanata] Karabiner-Elements already installed"; \
	else \
		echo "[kanata] installing Karabiner-Elements (VirtualHIDDevice driver)..."; \
		$(BREW_INSTALL) --cask karabiner-elements; \
	fi
	@echo "[kanata] NOTE: approve the driver under System Settings > Privacy &"
	@echo "[kanata]       Security, and grant kanata Input Monitoring access,"
	@echo "[kanata]       before it will capture keys."
