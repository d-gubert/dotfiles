# The Omarchy package backend. mk/arch.mk includes this file.
#
# `omarchy pkg add` reads the official repositories and `omarchy pkg aur add`
# builds from the AUR. Both check what is missing first, batch the rest into
# one transaction, pass --needed, and verify the result afterwards. No target
# needs a guard in front of them.

# pacman and yay ship with Omarchy, so there is nothing to bootstrap.
PKG_PREREQ :=

# Tools that only the AUR carries. The repositories carry everything else.
AUR_TOOLS := brave-browser carapace dvm enpass kanata rgx spotatui sttr vi-mongo

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
