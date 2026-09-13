# Debian and Ubuntu. Included by the main Makefile as mk/$(OS_FAMILY).mk.
#
# Every family file provides the same names -- BREW_PREFIX, STOW_OS_PKG and
# EXTRA_ESSENTIAL -- plus the install targets whose recipe differs by OS,
# whether it defines them itself or picks them up from mk/linux.mk. Keep the
# three families in sync when you add one.

include mk/linux.mk

STOW_OS_PKG := ubuntu
EXTRA_ESSENTIAL := logind-config install-i3
