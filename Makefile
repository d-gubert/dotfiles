# uname only tells Darwin from Linux, and the two Linux families need different
# packages, so resolve one OS family name up front and let it select the file
# that holds every OS-specific definition. Nothing below this point branches on
# the OS.
#
# Omarchy reports ID=omarchy with ID_LIKE=arch and plain Arch reports ID=arch
# with no ID_LIKE, so the match reads both fields, whole-word -- the "arch"
# inside "omarchy" would otherwise match on its own.
#
# Written without a `case` statement on purpose: an unbalanced `)` inside
# $(shell ...) ends the call early and make expands the wrong thing.
OS_FAMILY := $(shell uname | grep -q Darwin && echo darwin || { . /etc/os-release 2>/dev/null; echo " $$ID $$ID_LIKE " | grep -qw arch && echo arch || echo debian; })

# Defines the package backend (PKG_PREREQ, pkg_add and the PKG_<tool> name
# overrides), STOW_OS_PKG, EXTRA_ESSENTIAL, EXTRA_DEVELOPMENT, and every
# install target whose recipe differs by OS.
include mk/$(OS_FAMILY).mk

# Dotfiles are split into stow packages: common/ holds everything that is
# OS-agnostic, arch/, ubuntu/ and mac/ hold only what differs. Always stow
# common plus the package for this OS.
STOW_PKGS := common $(STOW_OS_PKG)

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo
	@echo "Targets:"
	@echo "  all            Install everything"
	@echo "  essential      Install essential packages"
	@echo "  development    Install development packages"
	@echo "  utilities      Install optional utility packages"

# ─────────────────────────────────────────────────────────────────────────────
# Aggregate targets
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all
all: essential development utilities

# ─────────────────────────────────────────────────────────────────────────────
# Essential
# ─────────────────────────────────────────────────────────────────────────────
# ESSENTIAL_TOOLS below covers everything that is only a package name. These
# are the ones that are not:
#
# brave-browser — official install script
# docker        — official script (docker-ce, not the apt docker.io snap)
# enpass        — vendor apt repo on Linux, cask on macOS
# kanata        — macOS also needs the Karabiner VirtualHIDDevice driver
# node          — installed by volta, and neovim wants it on PATH
# stow          — needed before any config is linked
# wezterm       — vendor apt repo on Linux, cask on macOS
# zsh           — also clones oh-my-zsh and four plugins

.PHONY: base-essential
base-essential: $(PKG_PREREQ) \
	stow \
	install-brave-browser \
	install-enpass \
	install-wezterm \
	install-zsh \
	install-docker \
	install-kanata \
	install-node
	@$(call pkg_add,$(ESSENTIAL_TOOLS))

.PHONY: essential
essential: base-essential $(EXTRA_ESSENTIAL)

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────
# DEVELOPMENT_TOOLS below covers the plain packages. These are the rest:
#
# dvm      — official install script (https://dvm.deno.dev) — Deno Version Manager
# meteor   — official install script (https://www.meteor.com/developers/install)
# node     — installed by volta
# vi-mongo — a package on Arch; on brew its tap must be trusted first
# volta    — official install script (https://volta.sh)

.PHONY: development
development: $(PKG_PREREQ) \
	stow \
	install-dvm \
	install-meteor \
	install-node \
	install-vi-mongo \
	$(EXTRA_DEVELOPMENT)
	@$(call pkg_add,$(DEVELOPMENT_TOOLS))

# ─────────────────────────────────────────────────────────────────────────────
# Utilities (Optional)
# ─────────────────────────────────────────────────────────────────────────────
# UTILITY_TOOLS below covers the plain packages. This is the rest:
#
# spotatui — prebuilt .deb from GitHub releases (not on the Linux brew tap)

.PHONY: utilities
utilities: $(PKG_PREREQ) \
	stow \
	install-spotatui
	@$(call pkg_add,$(UTILITY_TOOLS))

# ─────────────────────────────────────────────────────────────────────────────
# System pre-requisites
# ─────────────────────────────────────────────────────────────────────────────

# install-curl and the package backend both come from mk/<family>.mk.
.PHONY: install-stow
install-stow: $(PKG_PREREQ)
	@$(call pkg_add,stow)

# https://www.gnu.org/software/stow/manual/stow.html#Tree-unfolding-1
# -R (restow) unstows before stowing, which clears out symlinks left behind when
# a file moves between packages. Harmless on a fresh machine where nothing is
# stowed yet — stow just warns and carries on.
.PHONY: stow
stow: install-stow
	@echo "Stowing dotfiles: $(STOW_PKGS)"
	@echo
	@stow -R --no-folding -t ~ $(STOW_PKGS)


# ─────────────────────────────────────────────────────────────────────────────
# Fonts (nerd fonts, ligatures)
# ─────────────────────────────────────────────────────────────────────────────

FONT_TOOLS := fira-code-nerd

.PHONY: fonts
fonts: $(PKG_PREREQ)
	@$(call pkg_add,$(FONT_TOOLS))

# ─────────────────────────────────────────────────────────────────────────────
# Custom installation
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: install-meteor
install-meteor: install-curl
	@if command -v meteor >/dev/null 2>&1; then echo "[meteor] already installed"; else \
		echo "[meteor] installing via official script..."; \
		curl -fsSL https://install.meteor.com | sh; \
	fi


.PHONY: install-zsh
install-zsh: $(PKG_PREREQ)
	@$(call pkg_add,zsh)
	@if [ ! -d "$$HOME/.oh-my-zsh" ]; then \
		echo "[zsh:oh-my-zsh] installing..."; \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc; \
	else \
		echo "[zsh:oh-my-zsh] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then \
		echo "[zsh:powerlevel10k] installing..."; \
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
			"$$HOME/.oh-my-zsh/custom/themes/powerlevel10k"; \
	else \
		echo "[zsh:powerlevel10k] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then \
		echo "[zsh:zsh-autosuggestions] installing..."; \
		git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"; \
	else \
		echo "[zsh:zsh-autosuggestions] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then \
		echo "[zsh:zsh-syntax-highlighting] installing..."; \
		git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"; \
	else \
		echo "[zsh:zsh-syntax-highlighting] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-vi-mode" ]; then \
		echo "[zsh:zsh-vi-mode] installing..."; \
		git clone --depth=1 https://github.com/jeffreytse/zsh-vi-mode \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-vi-mode"; \
	else \
		echo "[zsh:zsh-vi-mode] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-autopair" ]; then \
		echo "[zsh:zsh-autopair] installing..."; \
		git clone --depth=1 https://github.com/hlissner/zsh-autopair \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-autopair"; \
	else \
		echo "[zsh:zsh-autopair] already installed"; \
	fi


.PHONY: install-tmux
install-tmux: pre-tmux
	@if [ -d "$$HOME/.tmux/plugins/tpm" ]; then echo "[tmux:tpm] already installed"; else \
		echo "[tmux:tpm] installing with git..."; \
		mkdir -p "$$HOME/.tmux/plugins"; \
		git clone --depth=1 --branch v3.1.0 https://github.com/tmux-plugins/tpm "$$HOME/.tmux/plugins/tpm"; \
		tmux new-session -d -s bootstrap_tpm; \
		"$$HOME/.tmux/plugins/tpm/bin/install_plugins"; \
		tmux kill-session -t bootstrap_tpm; \
	fi
	@if [ -d "$$HOME/.tmux/plugins/catppuccin" ]; then echo "[tmux:catppuccin] already installed"; else \
		echo "[tmux:catppuccin] installing with git..."; \
		mkdir -p "$$HOME/.tmux/plugins/catppuccin"; \
		git clone --depth 1 --branch v2.3.0 https://github.com/catppuccin/tmux.git "$$HOME/.tmux/plugins/catppuccin"; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Package manager installation
# ─────────────────────────────────────────────────────────────────────────────
#
# Each tool below is only a name in a package manager. A list holds them, not a
# target each. mk/<family>.mk maps a tool to the package name that its own
# package manager uses, through PKG_<tool>, and supplies PKG_INSTALL_CMD.
#
# Nothing guards these installs. brew, apt and pacman all skip a package that
# is already present, so a guard only repeats work the package manager does.

ESSENTIAL_TOOLS   := bat btop ffmpeg fd fzf glow herdr jq neovim ripgrep
DEVELOPMENT_TOOLS := ast-grep gh lazygit tealdeer
UTILITY_TOOLS     := carapace jwt-ui lazyjira tree-sitter

# No aggregate target installs these. Ask for them by name.
STANDALONE_TOOLS  := rgx sttr zellij

PKG_TOOLS := $(ESSENTIAL_TOOLS) $(DEVELOPMENT_TOOLS) $(UTILITY_TOOLS) \
             $(STANDALONE_TOOLS)

# The package name of a tool. It defaults to the name of the tool.
pkg_of = $(or $(PKG_$(1)),$(1))

# A family may have no package for a tool. PKG_SKIP lists those, and pkg_add
# reports them instead of failing the whole list.
pkg_wanted = $(filter-out $(PKG_SKIP),$(1))

# Install a list of tools with one command. One transaction is faster than one
# command per tool, and it asks for the password one time.
#
# `?=` on purpose: a backend that needs more than one command replaces this,
# and mk/<family>.mk is included above. mk/omarchy.mk does exactly that.
pkg_add ?= $(PKG_INSTALL_CMD) $(foreach t,$(call pkg_wanted,$(1)),$(call pkg_of,$(t)))

# Every tool in PKG_TOOLS gets an install-<tool> target from this rule.
.PHONY: $(addprefix install-,$(PKG_TOOLS))
$(addprefix install-,$(PKG_TOOLS)): install-%: $(PKG_PREREQ)
	@$(call pkg_add,$*)

# neovim drives some of its language servers through node.
install-neovim: install-node
