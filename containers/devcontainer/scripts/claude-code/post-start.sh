#!/usr/bin/env bash
#
# Runs IN THE CONTAINER from scripts/post-start.sh, on every start, and only when
# devcontainer.json declares the claude-code feature (feature.id).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Re-apply the egress firewall on every start (iptables state is not persisted).
# This is what makes `claude --dangerously-skip-permissions` safe to run here:
# egress is default-deny except for the assembled allowlist. The NET_ADMIN/NET_RAW
# capabilities it needs are contributed by this feature's initialize.sh.
#
# Run from the read-only /opt/devbox mount rather than a copy in the image, so
# editing the allowlist only needs a container restart. Invoked via `bash`
# because the exec bit comes from a host directory and can't be relied on.
#
# The variables are passed through explicitly because sudo resets the
# environment, and the allowlist is assembled out of the profile's file and
# DEVBOX_ALLOW_DOMAINS.
#
# Note this is our own script, not the /usr/local/bin/init-firewall.sh that the
# claude-code feature installs — that one is unused here.
sudo \
	DEVBOX_PROFILE="${DEVBOX_PROFILE:-default}" \
	DEVBOX_ALLOW_DOMAINS="${DEVBOX_ALLOW_DOMAINS:-}" \
	bash "$here/init-firewall.sh"

# Brings ~/.claude.json back after a rebuild — it sits outside the shared config
# volume, unlike the backups it is restored from.
bash "$here/restore-claude-json.sh"

# Installs the host's user-level skills, staged and mounted read-only by
# initialize.sh. Here rather than on-create so editing a skill on the host takes
# effect on a restart.
bash "$here/install-skills.sh"
