.DEFAULT_GOAL := help

BREW := /home/linuxbrew/.linuxbrew/bin/brew
BREW_INSTALL := $(BREW) install

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all            Install everything"
	@echo "  essential      Install essential packages"
	@echo "  development    Install development packages"
	@echo "  utilities      Install optional utility packages"
	@echo "  homebrew       Install Homebrew (required first)"

# ─────────────────────────────────────────────────────────────────────────────
# Aggregate targets
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all
all: essential development utilities

# ─────────────────────────────────────────────────────────────────────────────
# Homebrew (prerequisite for most packages)
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: homebrew
homebrew:
	@if command -v brew >/dev/null 2>&1; then \
		echo "[homebrew] already installed"; \
	else \
		echo "[homebrew] installing..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Essential
# ─────────────────────────────────────────────────────────────────────────────
# alacritty  — not in brew (deprecated/Linux); use apt
# zsh        — apt
# zellij     — brew
# kanata     — brew
# i3         — apt (Wayland session manager, not in brew for Linux)
# fzf        — brew
# ripgrep    — brew
# neovim     — brew
# stow       — brew
# gh         — brew
# glow       — brew
# jq         — brew
# arandr     — apt
# bat        — apt
# xclip      — apt
# docker     — official script (docker-ce, not the apt docker.io snap)
# btop       — apt
# ffmpeg     — apt

.PHONY: essential
essential: homebrew \
	install-alacritty \
	install-zsh \
	install-zellij \
	install-kanata \
	install-i3 \
	install-fzf \
	install-ripgrep \
	install-neovim \
	install-stow \
	install-gh \
	install-glow \
	install-jq \
	install-bat \
	install-xclip \
	install-docker \
	install-btop \
	install-ffmpeg \
	install-arandr

.PHONY: install-jq
install-jq:
	@if command -v jq >/dev/null 2>&1; then echo "[jq] already installed"; else \
		echo "[jq] installing via brew..."; \
		$(BREW_INSTALL) jq; \
	fi

.PHONY: install-arandr
install-arandr:
	@if command -v arandr >/dev/null 2>&1; then echo "[arandr] already installed"; else \
		echo "[arandr] installing via apt..."; \
		sudo apt-get install -y arandr; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────
# volta    — official install script (https://volta.sh)
# dvm      — official install script (https://dvm.deno.dev) — Deno Version Manager
# meteor   — official install script (https://www.meteor.com/developers/install)
# vi-mongo — brew
# lazygit  — brew
# ast-grep — brew

.PHONY: development
development: homebrew \
	install-volta \
	install-dvm \
	install-meteor \
	install-vi-mongo \
	install-lazygit \
	install-ast-grep

# ─────────────────────────────────────────────────────────────────────────────
# Utilities (Optional)
# ─────────────────────────────────────────────────────────────────────────────
# jiratui     — brew
# tealdeer    — brew
# carapace    — brew
# tree-sitter — brew

.PHONY: utilities
utilities: homebrew \
	install-jiratui \
	install-tealdeer \
	install-carapace \
	install-tree-sitter

.PHONY: install-alacritty
install-alacritty:
	@if command -v alacritty >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[alacritty] installing via apt..."; \
		sudo apt-get install -y alacritty; \
	fi

.PHONY: install-zsh
install-zsh:
	@if ! command -v zsh >/dev/null 2>&1; then \
		echo "[zsh] installing via apt..."; \
		sudo apt-get install -y zsh; \
	else \
		echo "[zsh] already installed"; \
	fi
	@# oh-my-zsh
	@if [ ! -d "$$HOME/.oh-my-zsh" ]; then \
		echo "[oh-my-zsh] installing..."; \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
	else \
		echo "[oh-my-zsh] already installed"; \
	fi
	@# powerlevel10k theme
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then \
		echo "[omz:powerlevel10k] installing..."; \
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
			"$$HOME/.oh-my-zsh/custom/themes/powerlevel10k"; \
	else \
		echo "[omz:powerlevel10k] already installed"; \
	fi
	@# zsh-autosuggestions
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then \
		echo "[omz:zsh-autosuggestions] installing..."; \
		git clone https://github.com/zsh-users/zsh-autosuggestions \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"; \
	else \
		echo "[omz:zsh-autosuggestions] already installed"; \
	fi
	@# zsh-syntax-highlighting
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then \
		echo "[omz:zsh-syntax-highlighting] installing..."; \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"; \
	else \
		echo "[omz:zsh-syntax-highlighting] already installed"; \
	fi
	@# zsh-vi-mode
	@if [ ! -d "$$HOME/.oh-my-zsh/custom/plugins/zsh-vi-mode" ]; then \
		echo "[omz:zsh-vi-mode] installing..."; \
		git clone https://github.com/jeffreytse/zsh-vi-mode \
			"$$HOME/.oh-my-zsh/custom/plugins/zsh-vi-mode"; \
	else \
		echo "[omz:zsh-vi-mode] already installed"; \
	fi

.PHONY: install-zellij
install-zellij:
	@if command -v zellij >/dev/null 2>&1; then echo "[zellij] already installed"; else \
		echo "[zellij] installing via brew..."; \
		$(BREW_INSTALL) zellij; \
	fi

.PHONY: install-kanata
install-kanata:
	@if command -v kanata >/dev/null 2>&1; then echo "[kanata] already installed"; else \
		echo "[kanata] installing via brew..."; \
		$(BREW_INSTALL) kanata; \
	fi

.PHONY: install-i3
install-i3:
	@if command -v i3 >/dev/null 2>&1; then echo "[i3] already installed"; else \
		echo "[i3] installing via apt..."; \
		sudo apt-get install -y i3; \
	fi

.PHONY: install-fzf
install-fzf:
	@if command -v fzf >/dev/null 2>&1; then echo "[fzf] already installed"; else \
		echo "[fzf] installing via brew..."; \
		$(BREW_INSTALL) fzf; \
	fi

.PHONY: install-ripgrep
install-ripgrep:
	@if command -v rg >/dev/null 2>&1; then echo "[ripgrep] already installed"; else \
		echo "[ripgrep] installing via brew..."; \
		$(BREW_INSTALL) ripgrep; \
	fi

.PHONY: install-neovim
install-neovim:
	@if command -v nvim >/dev/null 2>&1; then echo "[neovim] already installed"; else \
		echo "[neovim] installing via brew..."; \
		$(BREW_INSTALL) neovim; \
	fi

.PHONY: install-stow
install-stow:
	@if command -v stow >/dev/null 2>&1; then echo "[stow] already installed"; else \
		echo "[stow] installing via brew..."; \
		$(BREW_INSTALL) stow; \
	fi

.PHONY: install-gh
install-gh:
	@if command -v gh >/dev/null 2>&1; then echo "[gh] already installed"; else \
		echo "[gh] installing via brew..."; \
		$(BREW_INSTALL) gh; \
	fi

.PHONY: install-glow
install-glow:
	@if command -v glow >/dev/null 2>&1; then echo "[glow] already installed"; else \
		echo "[glow] installing via brew..."; \
		$(BREW_INSTALL) glow; \
	fi

.PHONY: install-bat
install-bat:
	@if command -v bat >/dev/null 2>&1; then echo "[bat] already installed"; else \
		echo "[bat] installing via apt..."; \
		sudo apt-get install -y bat; \
	fi

.PHONY: install-xclip
install-xclip:
	@if command -v xclip >/dev/null 2>&1; then echo "[xclip] already installed"; else \
		echo "[xclip] installing via apt..."; \
		sudo apt-get install -y xclip; \
	fi

.PHONY: install-docker
install-docker:
	@if command -v docker >/dev/null 2>&1; then echo "[docker] already installed"; else \
		echo "[docker] installing via official script (docker-ce)..."; \
		curl -fsSL https://get.docker.com | sudo sh; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] NOTE: log out and back in for group membership to take effect"; \
	fi

.PHONY: install-btop
install-btop:
	@if command -v btop >/dev/null 2>&1; then echo "[btop] already installed"; else \
		echo "[btop] installing via apt..."; \
		sudo apt-get install -y btop; \
	fi

.PHONY: install-ffmpeg
install-ffmpeg:
	@if command -v ffmpeg >/dev/null 2>&1; then echo "[ffmpeg] already installed"; else \
		echo "[ffmpeg] installing via apt..."; \
		sudo apt-get install -y ffmpeg; \
	fi


.PHONY: install-volta
install-volta:
	@if command -v volta >/dev/null 2>&1; then echo "[volta] already installed"; else \
		echo "[volta] installing via official script..."; \
		curl -fsSL https://get.volta.sh | bash; \
	fi

.PHONY: install-dvm
install-dvm:
	@if command -v dvm >/dev/null 2>&1; then echo "[dvm] already installed"; else \
		echo "[dvm] installing via official script..."; \
		curl -fsSL https://dvm.deno.dev | sh; \
	fi

.PHONY: install-meteor
install-meteor:
	@if command -v meteor >/dev/null 2>&1; then echo "[meteor] already installed"; else \
		echo "[meteor] installing via official script..."; \
		curl -fsSL https://install.meteor.com | sh; \
	fi

.PHONY: install-vi-mongo
install-vi-mongo:
	@if command -v vi-mongo >/dev/null 2>&1; then echo "[vi-mongo] already installed"; else \
		echo "[vi-mongo] installing via brew..."; \
		$(BREW_INSTALL) vi-mongo; \
	fi

.PHONY: install-lazygit
install-lazygit:
	@if command -v lazygit >/dev/null 2>&1; then echo "[lazygit] already installed"; else \
		echo "[lazygit] installing via brew..."; \
		$(BREW_INSTALL) lazygit; \
	fi

.PHONY: install-ast-grep
install-ast-grep:
	@if command -v ast-grep >/dev/null 2>&1 || command -v sg >/dev/null 2>&1; then echo "[ast-grep] already installed"; else \
		echo "[ast-grep] installing via brew..."; \
		$(BREW_INSTALL) ast-grep; \
	fi

.PHONY: install-jiratui
install-jiratui:
	@if command -v jiratui >/dev/null 2>&1; then echo "[jiratui] already installed"; else \
		echo "[jiratui] installing via brew..."; \
		$(BREW_INSTALL) jiratui; \
	fi

.PHONY: install-tealdeer
install-tealdeer:
	@if command -v tldr >/dev/null 2>&1; then echo "[tealdeer] already installed"; else \
		echo "[tealdeer] installing via brew..."; \
		$(BREW_INSTALL) tealdeer; \
	fi

.PHONY: install-carapace
install-carapace:
	@if command -v carapace >/dev/null 2>&1; then echo "[carapace] already installed"; else \
		echo "[carapace] installing via brew..."; \
		$(BREW_INSTALL) carapace; \
	fi

.PHONY: install-tree-sitter
install-tree-sitter:
	@if $(BREW) info tree-sitter 2>&1 | grep -i 'not installed'; then  \
		echo "[tree-sitter] installing via brew..."; \
		$(BREW_INSTALL) tree-sitter; \
	else \
		echo "[tree-sitter] already installed"; \
	fi
