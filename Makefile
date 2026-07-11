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
# alacritty  — not in brew (deprecated/Linux); use apt
# arandr     — apt
# bat        — brew
# btop       — brew
# docker     — official script (docker-ce, not the apt docker.io snap)
# ffmpeg     — brew
# fzf        — brew
# gh         — brew
# glow       — brew
# i3         — apt (X11 session manager, not in brew for Linux)
# jq         — brew
# kanata     — brew
# neovim     — brew
# ripgrep    — brew
# stow       — brew
# tmux       - brew
# xclip      — apt
# zellij     — brew
# zsh        — brew

.PHONY: essential
essential: homebrew \
	stow \
	install-alacritty \
	install-arandr \
	install-bat \
	install-btop \
	install-docker \
	install-ffmpeg \
	install-fzf \
	install-gh \
	install-glow \
	install-i3 \
	install-jq \
	install-kanata \
	install-neovim \
	install-rofi \
	install-ripgrep \
	install-tmux \
	install-xclip \
	install-zellij \
	install-zsh

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────
# ast-grep — brew
# devcontainer-cli — volta/npm (@devcontainers/cli) — for the sandbox devcontainer
# dvm      — official install script (https://dvm.deno.dev) — Deno Version Manager
# lazygit  — brew
# meteor   — official install script (https://www.meteor.com/developers/install)
# vi-mongo — brew
# tealdeer — brew
# volta    — official install script (https://volta.sh)

.PHONY: development
development: homebrew \
	stow \
	install-ast-grep \
	install-devcontainer-cli \
	install-dvm \
	install-lazygit \
	install-meteor \
	install-tealdeer \
	install-vi-mongo \
	install-volta

# ─────────────────────────────────────────────────────────────────────────────
# Utilities (Optional)
# ─────────────────────────────────────────────────────────────────────────────
# carapace    — brew
# jwt-ui      — brew
# lazyjira    — brew
# tree-sitter — brew
# spotatui    - brew

.PHONY: utilities
utilities: homebrew \
	stow \
	install-carapace \
	install-jwt-ui \
	install-lazyjira \
	install-spotatui \
	install-tree-sitter

# ─────────────────────────────────────────────────────────────────────────────
# Stow (symlink manager)
# ─────────────────────────────────────────────────────────────────────────────
# We create the symlinks for configuration BEFORE installing the software, otherwise
# stow would fail due to content already existing

.PHONY: stow
stow: install-stow
	@echo "Stowing dotfiles..."
	@echo
	@stow -t ~ ubuntu

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
# Fonts (nerd fonts, ligatures)
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: fonts
fonts: homebrew
	@if brew info font-fira-code 2>&1 | grep Installed >/dev/null; then echo "[fira-code] already installed"; else \
		echo "[fira-code] installing via brew..."; \
		brew install font-fira-code; \
		echo "[fira-code] installed"; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Custom installation
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: install-docker
install-docker:
	@if command -v docker >/dev/null 2>&1; then echo "[docker] already installed"; else \
		echo "[docker] installing via official script (docker-ce)..."; \
		curl -fsSL https://get.docker.com | sudo sh; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] NOTE: log out and back in for group membership to take effect"; \
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

.PHONY: install-devcontainer-cli
install-devcontainer-cli: install-volta
	@if command -v devcontainer >/dev/null 2>&1; then echo "[devcontainer-cli] already installed"; else \
		echo "[devcontainer-cli] installing via volta..."; \
		volta install @devcontainers/cli; \
	fi

.PHONY: install-zsh
install-zsh:
	@if ! command -v zsh >/dev/null 2>&1; then \
		echo "[zsh] installing via brew..."; \
		brew install zsh; \
	else \
		echo "[zsh] already installed"; \
	fi
	@if [ ! -d "$$HOME/.oh-my-zsh" ]; then \
		echo "[zsh:oh-my-zsh] installing..."; \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
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
install-tmux: homebrew
	@if command -v tmux >/dev/null 2>&1; then echo "[tmux] already installed"; else \
		echo "[tmux] installing via brew..."; \
		brew install tmux; \
		sudo ln -s "$$(which tmux)" /usr/bin/tmux; \
	fi
	@if [ -d "$$HOME/.tmux/plugins/tpm" ]; then echo "[tmux:tpm] already installed"; else \
		echo "[tmux:tpm] installing with git..."; \
		mkdir -p "$$HOME/.tmux/plugins/tpm"; \
		git clone --depth=1 --branch v3.1.0 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; \
		tmux new-session -d -s bootstrap_tpm; \
		"$$HOME/.tmux/plugins/tpm/bin/install_plugins"; \
		tmux kill-session bootstrap_tpm; \
	fi
	@if [ -d "$$HOME/.tmux/plugins/catppuccin" ]; then echo "[tmux:catppuccin] already installed"; else \
		echo "[tmux:catppuccin] installing with git..."; \
		mkdir -p "$$HOME/.tmux/plugins/catppuccin"; \
		git clone --depth 1 --branch v2.3.0 https://github.com/catppuccin/tmux.git "$$HOME/.tmux/plugins/catppuccin"; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# APT managed packages
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: install-xclip
install-xclip:
	@if command -v xclip >/dev/null 2>&1; then echo "[xclip] already installed"; else \
		echo "[xclip] installing via apt..."; \
		sudo apt-get install -y xclip; \
	fi

.PHONY: install-arandr
install-arandr:
	@if command -v arandr >/dev/null 2>&1; then echo "[arandr] already installed"; else \
		echo "[arandr] installing via apt..."; \
		sudo apt-get install -y arandr; \
	fi

.PHONY: install-alacritty
install-alacritty:
	@if command -v alacritty >/dev/null 2>&1; then echo "[alacritty] already installed"; else \
		echo "[alacritty] installing via apt..."; \
		sudo apt-get install -y alacritty; \
	fi

.PHONY: install-i3
install-i3:
	@if command -v i3 >/dev/null 2>&1; then echo "[i3] already installed"; else \
		echo "[i3] installing via apt..."; \
		sudo apt-get install -y i3; \
	fi

.PHONY: install-rofi
install-rofi:
	@if command -v rofi >/dev/null 2>&1; then echo "[rofi] already installed"; else \
		echo "[rofi] installing via apt..."; \
		sudo apt-get install -y rofi; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Homebrew managed packages
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: install-bat
install-bat: homebrew
	@if command -v bat >/dev/null 2>&1; then echo "[bat] already installed"; else \
		echo "[bat] installing via brew..."; \
		brew install bat; \
	fi

.PHONY: install-btop
install-btop: homebrew
	@if command -v btop >/dev/null 2>&1; then echo "[btop] already installed"; else \
		echo "[btop] installing via brew..."; \
		brew install btop; \
	fi

.PHONY: install-jq
install-jq: homebrew
	@if command -v jq >/dev/null 2>&1; then echo "[jq] already installed"; else \
		echo "[jq] installing via brew..."; \
		brew install jq; \
	fi

.PHONY: install-jwt-ui
install-jwt-ui: homebrew
	@if command -v jwt-ui >/dev/null 2>&1; then echo "[jwt-ui] already installed"; else \
		echo "[jwt-ui] installing via brew..."; \
		brew install jwt-rs/jwt-ui/jwt-ui; \
	fi

.PHONY: install-zellij
install-zellij: homebrew
	@if command -v zellij >/dev/null 2>&1; then echo "[zellij] already installed"; else \
		echo "[zellij] installing via brew..."; \
		brew install zellij; \
	fi

.PHONY: install-kanata
install-kanata: homebrew
	@if command -v kanata >/dev/null 2>&1; then echo "[kanata] already installed"; else \
		echo "[kanata] installing via brew..."; \
		brew install kanata; \
	fi

.PHONY: install-ffmpeg
install-ffmpeg: homebrew
	@if command -v ffmpeg >/dev/null 2>&1; then echo "[ffmpeg] already installed"; else \
		echo "[ffmpeg] installing via apt..."; \
		brew install ffmpeg; \
	fi

.PHONY: install-fzf
install-fzf: homebrew
	@if command -v fzf >/dev/null 2>&1; then echo "[fzf] already installed"; else \
		echo "[fzf] installing via brew..."; \
		brew install fzf; \
	fi

.PHONY: install-ripgrep
install-ripgrep: homebrew
	@if command -v rg >/dev/null 2>&1; then echo "[ripgrep] already installed"; else \
		echo "[ripgrep] installing via brew..."; \
		brew install ripgrep; \
	fi

.PHONY: install-neovim
install-neovim: homebrew
	@if command -v nvim >/dev/null 2>&1; then echo "[neovim] already installed"; else \
		echo "[neovim] installing via brew..."; \
		brew install neovim; \
	fi

.PHONY: install-stow
install-stow: homebrew
	@if command -v stow >/dev/null 2>&1; then echo "[stow] already installed"; else \
		echo "[stow] installing via brew..."; \
		brew install stow; \
	fi

.PHONY: install-gh
install-gh: homebrew
	@if command -v gh >/dev/null 2>&1; then echo "[gh] already installed"; else \
		echo "[gh] installing via brew..."; \
		brew install gh; \
	fi

.PHONY: install-glow
install-glow: homebrew
	@if command -v glow >/dev/null 2>&1; then echo "[glow] already installed"; else \
		echo "[glow] installing via brew..."; \
		brew install glow; \
	fi

.PHONY: install-vi-mongo
install-vi-mongo: homebrew
	@if command -v vi-mongo >/dev/null 2>&1; then echo "[vi-mongo] already installed"; else \
		echo "[vi-mongo] installing via brew..."; \
		brew install vi-mongo; \
	fi

.PHONY: install-lazygit
install-lazygit: homebrew
	@if command -v lazygit >/dev/null 2>&1; then echo "[lazygit] already installed"; else \
		echo "[lazygit] installing via brew..."; \
		brew install lazygit; \
	fi

.PHONY: install-ast-grep
install-ast-grep:
	@if command -v ast-grep >/dev/null 2>&1 || command -v sg >/dev/null 2>&1; then echo "[ast-grep] already installed"; else \
		echo "[ast-grep] installing via brew..."; \
		brew install ast-grep; \
	fi

.PHONY: install-lazyjira
install-lazyjira: homebrew
	@if command -v lazyjira >/dev/null 2>&1; then echo "[lazyjira] already installed"; else \
		echo "[lazyjira] installing via brew..."; \
		brew install textfuel/tap/lazyjira; \
	fi

.PHONY: install-rgx
install-rgx: homebrew
	@if command -v rgx >/dev/null 2>&1; then echo "[rgx] already installed"; else \
		echo "[rgx] installing via brew..."; \
		brew install brevity1swos/tap/rgx; \
	fi

.PHONY: install-spotatui
install-spotatui: homebrew
	@if command -v spotatui >/dev/null 2>&1; then echo "[spotatui] already installed"; else \
		echo "[spotatui] installing via brew..."; \
		brew install spotatui; \
	fi

.PHONY: install-sttr
install-sttr: homebrew
	@if command -v sttr >/dev/null 2>&1; then echo "[sttr] already installed"; else \
		echo "[sttr] installing via brew..."; \
		brew install sttr; \
	fi

.PHONY: install-tealdeer
install-tealdeer: homebrew
	@if command -v tldr >/dev/null 2>&1; then echo "[tealdeer] already installed"; else \
		echo "[tealdeer] installing via brew..."; \
		brew install tealdeer; \
	fi

.PHONY: install-carapace
install-carapace: homebrew
	@if command -v carapace >/dev/null 2>&1; then echo "[carapace] already installed"; else \
		echo "[carapace] installing via brew..."; \
		brew install carapace; \
	fi

.PHONY: install-tree-sitter
install-tree-sitter:
	@if brew info tree-sitter 2>&1 | grep -i 'not installed'; then  \
		echo "[tree-sitter] installing via brew..."; \
		brew install tree-sitter; \
	else \
		echo "[tree-sitter] already installed"; \
	fi
