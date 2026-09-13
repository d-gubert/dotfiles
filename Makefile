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

# Defines BREW_PREFIX, STOW_OS_PKG, EXTRA_ESSENTIAL and every install target
# whose recipe differs by OS.
include mk/$(OS_FAMILY).mk

# Dotfiles are split into stow packages: common/ holds everything that is
# OS-agnostic, arch/, ubuntu/ and mac/ hold only what differs. Always stow
# common plus the package for this OS.
STOW_PKGS := common $(STOW_OS_PKG)

BREW := $(BREW_PREFIX)/bin/brew
BREW_INSTALL := $(BREW) install --no-ask

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
# vi-mongo — brew, but its tap must be trusted first
# volta    — official install script (https://volta.sh)

.PHONY: development
development: $(PKG_PREREQ) \
	stow \
	install-dvm \
	install-meteor \
	install-node \
	install-vi-mongo \
	install-volta
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

# Prerequisite for the `curl | sh` script installers (homebrew, docker, volta, dvm, meteor)
.PHONY: install-curl
install-curl:
	@if command -v curl >/dev/null 2>&1; then echo "[curl] already installed"; else \
		echo "[curl] installing via apt..."; \
		sudo apt-get install -y curl; \
	fi

.PHONY: homebrew
homebrew: install-curl
	@if command -v brew >/dev/null 2>&1; then echo "[homebrew] already installed"; else \
		echo "[homebrew] installing..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		eval "$$($(BREW) shellenv)"; \
	fi

.PHONY: install-stow
install-stow: homebrew
	@if command -v stow >/dev/null 2>&1; then echo "[stow] already installed"; else \
		echo "[stow] installing via brew..."; \
		$(BREW_INSTALL) stow; \
	fi

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

.PHONY: fonts
fonts: homebrew
	@if $(BREW) info font-fira-code-nerd-font 2>&1 | grep -q Installed; then echo "[fira-code] already installed"; else \
		echo "[fira-code] installing via brew..."; \
		$(BREW_INSTALL) font-fira-code-nerd-font; \
		echo "[fira-code] installed"; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Custom installation
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: install-docker
install-docker: install-curl
	@if command -v docker >/dev/null 2>&1; then echo "[docker] already installed"; else \
		echo "[docker] installing via official script (docker-ce)..."; \
		curl -fsSL https://get.docker.com | sudo sh; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] NOTE: log out and back in for group membership to take effect"; \
	fi

.PHONY: install-brave-browser
install-brave-browser: install-curl
	@if command -v brave-browser >/dev/null 2>&1; then echo "[brave-browser] already installed"; else \
		echo "[brave-browser] installing via official script..."; \
		curl -fsS https://dl.brave.com/install.sh | sh; \
	fi

.PHONY: install-volta
install-volta: install-curl
	@if command -v volta >/dev/null 2>&1; then echo "[volta] already installed"; else \
		echo "[volta] installing via official script..."; \
		curl -fsSL https://get.volta.sh | bash; \
	fi

.PHONY: install-node
install-node: install-volta
	@if command -v node >/dev/null 2>&1; then echo "[node] already installed"; else \
		echo "[node] installing with volta..."; \
		volta install node; \
	fi

.PHONY: install-dvm
install-dvm: install-curl
	@if command -v dvm >/dev/null 2>&1; then echo "[dvm] already installed"; else \
		echo "[dvm] installing via official script..."; \
		curl -fsSL https://dvm.deno.dev | sh; \
	fi

.PHONY: install-meteor
install-meteor: install-curl
	@if command -v meteor >/dev/null 2>&1; then echo "[meteor] already installed"; else \
		echo "[meteor] installing via official script..."; \
		curl -fsSL https://install.meteor.com | sh; \
	fi


.PHONY: install-zsh
install-zsh: homebrew install-curl
	@if command -v zsh >/dev/null 2>&1; then echo "[zsh] already installed"; else \
		echo "[zsh] installing via brew..."; \
		$(BREW_INSTALL) zsh; \
	fi
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

# Install a list of tools with one command. One transaction is faster than one
# command per tool, and it asks for the password one time.
pkg_add = $(PKG_INSTALL_CMD) $(foreach t,$(1),$(call pkg_of,$(t)))

# Every tool in PKG_TOOLS gets an install-<tool> target from this rule.
.PHONY: $(addprefix install-,$(PKG_TOOLS))
$(addprefix install-,$(PKG_TOOLS)): install-%: $(PKG_PREREQ)
	@$(call pkg_add,$*)

# neovim drives some of its language servers through node.
install-neovim: install-node
