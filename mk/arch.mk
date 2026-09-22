# Arch and Omarchy. Included by the main Makefile as mk/$(OS_FAMILY).mk.
#
# Every family file provides the same names -- PKG_PREREQ, STOW_OS_PKG,
# EXTRA_ESSENTIAL, EXTRA_DEVELOPMENT -- plus the install targets whose recipe
# differs by OS. Keep the three families in sync when you add one.

include mk/omarchy.mk
include mk/systemd.mk

STOW_OS_PKG := arch

# i3 is an X11 window manager and Omarchy runs Hyprland, so `essential` does
# not install it here.
EXTRA_ESSENTIAL := logind-config

# mise manages the node toolchain, which is what arch/.zshrc.os wires into the
# shell. volta is not installed on this family.
EXTRA_DEVELOPMENT := install-mise

.PHONY: install-curl
install-curl:
	@$(call pkg_add,curl)

.PHONY: install-mise
install-mise:
	@$(call pkg_add,mise)

# `mise use -g` writes the version to ~/.config/mise/config.toml, so the choice
# survives a new shell. The shims are already on PATH from arch/.zshrc.os.
.PHONY: install-node
install-node: install-mise
	@if command -v node >/dev/null 2>&1; then echo "[node] already installed"; else \
		echo "[node] installing with mise..."; \
		mise use -g node@lts; \
	fi

# Omarchy also offers `omarchy install browser brave`, which opens a floating
# terminal. The package is the predictable choice inside a Makefile.
.PHONY: install-brave-browser
install-brave-browser:
	@$(call pkg_add,brave-browser)

.PHONY: install-enpass
install-enpass:
	@$(call pkg_add,enpass)

.PHONY: install-alacritty
install-alacritty:
	@$(call pkg_add,alacritty)

.PHONY: install-wezterm
install-wezterm:
	@$(call pkg_add,wezterm)

# stow links arch/.config/systemd/user/kanata.service into ~, and `enable`
# turns that unit into a login-time service, so stow has to run first.
#
# systemd follows the stow symlink and writes the repository path itself into
# default.target.wants, not the path under ~/.config. Move this checkout and
# the unit stops starting, until `systemctl --user reenable kanata.service`
# rewrites that link.
.PHONY: install-kanata
install-kanata: uinput-config stow
	@$(call pkg_add,kanata)
	@systemctl --user daemon-reload
	@if systemctl --user is-enabled kanata.service >/dev/null 2>&1; then \
		echo "[kanata] service already enabled"; \
	else \
		echo "[kanata] enabling the user service..."; \
		systemctl --user enable kanata.service; \
	fi

.PHONY: install-spotatui
install-spotatui:
	@$(call pkg_add,spotatui)

.PHONY: install-vi-mongo
install-vi-mongo:
	@$(call pkg_add,vi-mongo)

.PHONY: install-dvm
install-dvm:
	@$(call pkg_add,dvm)

.PHONY: pre-tmux
pre-tmux:
	@$(call pkg_add,tmux)

# Arch ships docker as a package, and the daemon needs an explicit enable.
.PHONY: install-docker
install-docker:
	@$(call pkg_add,docker docker-compose)
	@sudo systemctl enable --now docker.service
	@if id -nG "$$USER" | grep -qw docker; then echo "[docker] group already set"; else \
		sudo usermod -aG docker $$USER; \
		echo "[docker] NOTE: log out and back in for group membership to take effect"; \
	fi
