#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from scripts/update-content.sh, after the profile's
# setup.sh, and only when devcontainer.json declares the playwright-deps feature
# (feature.id).
#
# Downloads the browser builds into the shared cache volume mounted at
# ~/.cache/ms-playwright. The feature installs the OS libraries those builds
# need; it deliberately does not install Playwright itself.
#
# Why the browsers come from the *workspace's* Playwright and not from a global
# one: a browser build only works with the version that fetched it, so the
# version that matters is the one the repo pins. That is also why this runs after
# the profile's setup.sh — until dependencies are installed there is no CLI to
# call. A workspace that doesn't use Playwright simply has none, and this is a
# no-op.
#
# Set DEVBOX_PLAYWRIGHT_CMD in a profile's `env` when the CLI isn't at the
# workspace root — a monorepo that pins it in one package, say:
#
#     DEVBOX_PLAYWRIGHT_CMD=yarn workspace @acme/web playwright
#
# and DEVBOX_PLAYWRIGHT_BROWSERS to change the engine list (default: chromium;
# match it to the feature's install*Deps options in devcontainer.json).
set -euo pipefail

log() { printf '\033[1;34m[update-content:playwright]\033[0m %s\n' "$1"; }

cd "$DEVBOX_WORKSPACE"

# Word-split on purpose: both are lists written as plain strings in a profile's
# env file, which has no way to say "array".
# shellcheck disable=SC2206
browsers=(${DEVBOX_PLAYWRIGHT_BROWSERS:-chromium})

if [ -n "${DEVBOX_PLAYWRIGHT_CMD:-}" ]; then
	# shellcheck disable=SC2206
	cli=($DEVBOX_PLAYWRIGHT_CMD)
elif [ -x node_modules/.bin/playwright ]; then
	cli=(node_modules/.bin/playwright)
else
	log "no Playwright in this workspace — skipping the browser download"
	log "(set DEVBOX_PLAYWRIGHT_CMD in the profile's env if it lives in a sub-package)"
	exit 0
fi

log "installing browsers: ${browsers[*]}"
# No --with-deps: that shells out to apt, which the egress firewall does not
# allowlist, and the feature has already installed the same packages at build
# time. A no-op once the build is in the cache volume.
"${cli[@]}" install "${browsers[@]}"
