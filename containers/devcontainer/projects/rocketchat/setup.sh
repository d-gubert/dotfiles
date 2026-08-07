#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from scripts/update-content.sh, on create and rebuild,
# as `vscode`, with $DEVBOX_WORKSPACE as cwd and the network still unrestricted —
# the egress firewall is applied later, by postStartCommand.
#
# Everything Rocket.Chat needs that the generic image deliberately does not have:
# the pinned Meteor distribution, the pinned Deno, and the workspace's own
# dependencies. The toolchains land in $DEVBOX_TOOLS, a volume shared by every
# workspace on this profile, so they are downloaded once per machine rather than
# once per checkout and never again on a rebuild.
#
# Pins are read straight out of the checkout, so there is no second place to bump:
#   apps/meteor/.meteor/release -> meteor
#   .tool-versions              -> deno
#   package.json (volta.*)      -> node/yarn, handled by Volta with no help here
set -euo pipefail

log() { printf '\033[1;34m[rocketchat]\033[0m %s\n' "$1"; }

cd "$DEVBOX_WORKSPACE"

# --- Claim the two build volumes ---------------------------------------------
# compose/service-volumes.yml mounts them inside the workspace; a named volume's
# mount point lands root:root, so yarn and meteor — running as vscode — would get
# EACCES creating anything under them.
#
# These target the *volumes*, not the host repo: each is mounted over the bind
# mount at its path, so the host's own node_modules and .meteor/local are
# shadowed and untouched. Not recursive: everything below is created as vscode,
# and a recursive walk of a populated node_modules would add minutes to every
# create.
log "claiming build volume mount points"
sudo chown vscode:vscode node_modules apps/meteor/.meteor/local

# --- Meteor -------------------------------------------------------------------
# The ?release= pin matters: install.meteor.com defaults to the newest release,
# but the project runs whatever apps/meteor/.meteor/release says, so installing
# the newest one means the first in-project command downloads the pinned
# meteor-tool anyway and the bundled copy is dead weight.
meteor_release="$(sed 's/^METEOR@//' apps/meteor/.meteor/release)"
if [ ! -d "$METEOR_WAREHOUSE_DIR/packages/meteor-tool/$meteor_release" ]; then
	log "installing Meteor $meteor_release into $METEOR_WAREHOUSE_DIR (~1GB, once per machine)"
	# The installer hardcodes $HOME/.meteor as the warehouse it unpacks into, so
	# it is pointed at a throwaway home and the result moved into place. Merged
	# rather than replaced: the warehouse may already hold another release from a
	# branch that pins a different one, and they coexist by design.
	tmp_home="$(mktemp -d)"
	curl -fsSL "https://install.meteor.com/?release=$meteor_release" | HOME="$tmp_home" sh
	mkdir -p "$METEOR_WAREHOUSE_DIR"
	cp -a "$tmp_home/.meteor/." "$METEOR_WAREHOUSE_DIR/"
	rm -rf "$tmp_home"
fi

# The launcher lives in the container's writable layer, so unlike the warehouse it
# is gone after a rebuild. No PATH entry is needed: the warehouse has `meteor` at
# its root, not under bin/.
if [ ! -e /usr/local/bin/meteor ]; then
	log "linking the meteor launcher into /usr/local/bin"
	sudo ln -sf "$METEOR_WAREHOUSE_DIR/meteor" /usr/local/bin/meteor
fi

# --- Deno ---------------------------------------------------------------------
deno_version="$(awk '$1=="deno" { print $2 }' .tool-versions)"
if [ -n "$deno_version" ] && [ ! -x "$DENO_INSTALL/bin/deno" ]; then
	log "installing Deno $deno_version into $DENO_INSTALL"
	mkdir -p "$DENO_INSTALL"
	curl -fsSL https://deno.land/install.sh | sh -s "v$deno_version"
fi
if [ -x "$DENO_INSTALL/bin/deno" ] && [ ! -e /usr/local/bin/deno ]; then
	sudo ln -sf "$DENO_INSTALL/bin/deno" /usr/local/bin/deno
fi

# --- The workspace ------------------------------------------------------------
# Node and Yarn need no handling: Volta reads package.json's `volta` pins and
# fetches the right versions on the first call.
log "installing dependencies"
yarn install

log "building workspace packages"
yarn build
