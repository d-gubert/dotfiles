# Shared Linux definitions, included by both mk/debian.mk and mk/arch.mk.
#
# These recipes are the ones the old Makefile ran in the `else` branch of
# every `ifeq ($(OS_NAME),Darwin)`, so they assume apt and Homebrew. That is
# wrong on Arch, which is why mk/arch.mk will stop including this file once
# its targets are rewritten against `omarchy pkg`. Until then both families
# behave exactly as they did before the split.

include mk/brew.mk

BREW_PREFIX := /home/linuxbrew/.linuxbrew


# ─────────────────────────────────────────────────────────────────────────────
# Linux exclusive targets
# ─────────────────────────────────────────────────────────────────────────────

# logind — make the laptop do nothing when the lid closes on AC power
#          (battery still suspends). Lives under system/ mirroring /.

.PHONY: logind-config
logind-config:
	@if sudo cmp -s system/etc/systemd/logind.conf.d/lid.conf /etc/systemd/logind.conf.d/lid.conf 2>/dev/null; then \
		echo "[logind] already configured"; \
	else \
		echo "[logind] installing lid drop-in to /etc..."; \
		sudo install -D -m 0644 system/etc/systemd/logind.conf.d/lid.conf /etc/systemd/logind.conf.d/lid.conf; \
		sudo systemctl kill -s HUP systemd-logind; \
	fi

# i3 installation and dependencies
#
# maim                        - screenshot tool
# pulseaudio                  - audio control tool
# playerctl                   - media player control tool
# xserver-xorg-input-libinput - input (keyboard, mouse, etc) for x11
# xinput                      - input (keyboard, mouse, etc) for x11
# network-manager-applet      - i3 tray icon nm-applet
# blueman                     - bluetooth manager
# arandr                      - xrandr GUI display management
# xclip                       - clipboard manager
# slop                        - screen area selector (also used by maim)
# rofi                        - general purpose menu selector (fzf for GUI)
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
install-kanata: homebrew
	@if command -v kanata >/dev/null 2>&1; then echo "[kanata] already installed"; else \
		echo "[kanata] installing via brew..."; \
		$(BREW_INSTALL) kanata; \
	fi
