#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from devcontainer.json's updateContentCommand, on
# create/rebuild and whenever the tool decides the content is stale.
#
# This is where the workspace is made usable — which, in a container that knows
# nothing about the repo it is holding, means running the profile's setup.sh and
# then whatever the declared features need from *inside* an installed workspace.
#
# It runs after onCreateCommand — so the volumes it writes into are already
# claimed — and before postStartCommand, which is what applies the egress
# firewall. That ordering is load-bearing for anything here that downloads: at
# this point there is still unrestricted network.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/features.sh"

log() { printf '\033[1;34m[update-content]\033[0m %s\n' "$1"; }

cd "$DEVBOX_WORKSPACE"

# The profile's own setup: install dependencies, fetch a toolchain into
# $DEVBOX_TOOLS, generate whatever the repo needs before it can build. Nothing
# is assumed about the workspace — a profile with no setup.sh (`default`, unless
# you give it one) leaves you with the bare toolchain image and a shell.
setup="$DEVBOX_HOME/projects/$DEVBOX_PROFILE/setup.sh"
if [ -f "$setup" ]; then
	log "running profile setup: projects/$DEVBOX_PROFILE/setup.sh"
	# Via `bash` because the exec bit comes from a read-only host mount and can't
	# be relied on.
	bash "$setup"
else
	log "profile $DEVBOX_PROFILE has no setup.sh — nothing to install"
fi

# After the profile, so a hook can rely on the workspace's node_modules — which
# is how a feature gets at a tool pinned by the repo rather than a version of its
# own.
run_feature_hooks update-content.sh
