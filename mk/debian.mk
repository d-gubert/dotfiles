# Debian and Ubuntu. Included by the main Makefile as mk/$(OS_FAMILY).mk.
#
# Every family file provides the same names -- PKG_PREREQ, STOW_OS_PKG,
# EXTRA_ESSENTIAL, EXTRA_DEVELOPMENT -- plus the install targets whose recipe
# differs by OS. Keep the three families in sync when you add one.

include mk/brew.mk
include mk/scripts.mk
include mk/systemd.mk

BREW_PREFIX := /home/linuxbrew/.linuxbrew
STOW_OS_PKG := ubuntu
EXTRA_ESSENTIAL := logind-config install-i3

.PHONY: install-curl
install-curl:
	@if command -v curl >/dev/null 2>&1; then echo "[curl] already installed"; else \
		echo "[curl] installing via apt..."; \
		sudo apt-get install -y curl; \
	fi

.PHONY: install-i3
install-i3:
	@if apt list i3 2>&1 | grep -q installed; then echo "[i3] already installed"; else \
		echo "[i3] installing via apt with dependencies..."; \
		sudo apt-get install -y i3 maim pulseaudio playerctl xserver-xorg-input-libinput xinput network-manager-applet blueman arandr rofi xclip slop; \
	fi

.PHONY: install-spotatui
# Not published on the Linux brew tap
install-spotatui: install-curl install-jq
	@if command -v spotatui >/dev/null 2>&1; then echo "[spotatui] already installed"; else \
		echo "[spotatui] resolving latest release..."; \
		deb_url=$$(curl -fsSL https://api.github.com/repos/LargeModGames/spotatui/releases/latest \
			| jq -r '.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url'); \
		if [ -z "$$deb_url" ]; then echo "[spotatui] ERROR: no amd64 .deb asset in latest release"; exit 1; fi; \
		tmp=$$(mktemp -d); \
		deb="$$tmp/$$(basename "$$deb_url")"; \
		echo "[spotatui] downloading $$(basename "$$deb_url")..."; \
		curl -fsSL "$$deb_url" -o "$$deb"; \
		curl -fsSL "$$deb_url.sha256" -o "$$deb.sha256"; \
		echo "[spotatui] verifying sha256..."; \
		if ! ( cd "$$tmp" && sha256sum -c "$$(basename "$$deb").sha256" ); then \
			echo "[spotatui] ERROR: checksum verification failed"; rm -rf "$$tmp"; exit 1; \
		fi; \
		echo "[spotatui] installing via apt..."; \
		sudo apt-get install -y "$$deb"; \
		rm -rf "$$tmp"; \
	fi

.PHONY: pre-tmux
# Install via apt-get on Linux, homebrew version has weird bugs
pre-tmux:
	@if command -v tmux >/dev/null 2>&1; then echo "[tmux] already installed"; else \
		echo "[tmux] installing via apt..."; \
		sudo apt-get install tmux; \
	fi

.PHONY: install-enpass
install-enpass:
	@if apt list enpass 2>/dev/null | grep -q installed; then echo "[enpass] already installed"; else \
		echo "[enpass] installing via apt..."; \
		echo "deb https://apt.enpass.io/  stable main" | sudo tee /etc/apt/sources.list.d/enpass.list; \
		wget -O - https://apt.enpass.io/keys/enpass-linux.key | sudo tee /etc/apt/trusted.gpg.d/enpass.asc; \
		sudo apt-get -y update; \
		sudo apt-get -y install enpass; \
	fi

.PHONY: install-alacritty
install-alacritty:
	@if command -v alacritty >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[alacritty] installing via apt..."; \
		sudo apt-get install -y alacritty; \
	fi

.PHONY: install-wezterm
install-wezterm:
	@if command -v wezterm >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[wezterm] installing via apt..."; \
		curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg; \
		echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list; \
		sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg; \
	fi

.PHONY: install-kanata
install-kanata: homebrew uinput-config
	@if command -v kanata >/dev/null 2>&1; then echo "[kanata] already installed"; else \
		echo "[kanata] installing via brew..."; \
		$(BREW_INSTALL) kanata; \
	fi
