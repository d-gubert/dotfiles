# Everything that only Omarchy needs. mk/arch.mk includes this file.
#
# The first half is the package backend. The second half sets the desktop
# preferences that no config file carries.
#
# `omarchy pkg add` reads the official repositories and `omarchy pkg aur add`
# builds from the AUR. Both check what is missing first, batch the rest into
# one transaction, pass --needed, and verify the result afterwards. No target
# needs a guard in front of them.

# pacman and yay ship with Omarchy, so there is nothing to bootstrap.
PKG_PREREQ :=

# Tools that only the AUR carries. The repositories carry everything else.
AUR_TOOLS := brave-browser carapace dvm enpass kanata mise rgx spotatui sttr \
             vi-mongo

# lazyjira ships only through a Homebrew tap. Arch has no package for it, so
# pkg_add reports it instead of failing the whole list.
PKG_SKIP := lazyjira

# Package names that differ from the name of the tool.
PKG_brave-browser  := brave-bin
PKG_carapace       := carapace-bin
PKG_enpass         := enpass-bin
PKG_fira-code-nerd := ttf-firacode-nerd
PKG_gh             := github-cli
PKG_kanata         := kanata-bin
# omarchy-base.packages installs mise-bin, and mise-bin conflicts with the
# repository `mise`. Ask for the name that Omarchy actually uses.
PKG_mise           := mise-bin
# omarchy-base.packages installs tldr, and tealdeer conflicts with it. Both
# provide the tldr command, so ask for the one that is already there.
PKG_tealdeer       := tldr

# One list can hold both repository and AUR packages, and the two need separate
# commands, so this backend replaces pkg_add instead of setting PKG_INSTALL_CMD.
_repo_names = $(foreach t,$(filter-out $(AUR_TOOLS),$(call pkg_wanted,$(1))),$(call pkg_of,$(t)))
_aur_names  = $(foreach t,$(filter $(AUR_TOOLS),$(call pkg_wanted,$(1))),$(call pkg_of,$(t)))

# `true` closes the command so that a fully skipped list still runs.
pkg_add = set -e; \
	$(if $(filter $(PKG_SKIP),$(1)),echo "[skip] no Arch package for: $(filter $(PKG_SKIP),$(1))";) \
	$(if $(call _repo_names,$(1)),omarchy pkg add $(call _repo_names,$(1));) \
	$(if $(call _aur_names,$(1)),omarchy pkg aur add $(call _aur_names,$(1));) \
	true

# ─────────────────────────────────────────────────────────────────────────────
# Desktop preferences
# ─────────────────────────────────────────────────────────────────────────────
# Config files carry the rest of the desktop setup, and stow links them from
# arch/: the four hypr/*.lua files, alacritty/alacritty.toml,
# omarchy/shell.toml, xdg-terminals.list and the wezterm desktop entry. See the
# table in README.md. The preferences below have no config file. Omarchy keeps
# them in ~/.local/state/omarchy, which is runtime state, so this target sets
# them through the commands that own that state.
#
# `omarchy theme bg set` resolves the path against the current theme, so the
# theme must come first.
#
# `omarchy toggle <flag> on` sets the flag. The bare `omarchy toggle
# screensaver` flips it, which would turn the screensaver back on for a second
# run of this target.
.PHONY: omarchy-prefs
omarchy-prefs:
	@echo "[omarchy] theme: Catppuccin"
	@omarchy theme set catppuccin
	@echo "[omarchy] background: Totoro"
	@omarchy theme bg set "$$HOME/.local/state/omarchy/current/theme/backgrounds/1-totoro.png"
	@echo "[omarchy] screensaver: off"
	@omarchy toggle screensaver-off on
