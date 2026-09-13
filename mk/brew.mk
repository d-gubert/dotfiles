# The Homebrew backend. mk/darwin.mk and mk/linux.mk both include this file.
#
# A family file selects a backend by defining PKG_PREREQ, PKG_INSTALL_CMD and
# any PKG_<tool> name overrides. The main Makefile reads those three names and
# never mentions brew.

# brew must exist before the pattern rule runs.
PKG_PREREQ := homebrew

# Recursive on purpose. BREW_INSTALL comes from the main Makefile, which reads
# BREW_PREFIX from the family file, so it is not defined yet at include time.
PKG_INSTALL_CMD = $(BREW_INSTALL)

# Tools whose formula name is not the name of the tool.
PKG_jwt-ui   := jwt-rs/jwt-ui/jwt-ui
PKG_lazyjira := textfuel/tap/lazyjira
PKG_rgx      := brevity1swos/tap/rgx

# vi-mongo needs its tap trusted before the install, so it keeps a recipe.
.PHONY: install-vi-mongo
install-vi-mongo: homebrew
	$(BREW) tap kopecmaciej/vi-mongo
	$(BREW) trust kopecmaciej/vi-mongo
	$(BREW_INSTALL) vi-mongo
