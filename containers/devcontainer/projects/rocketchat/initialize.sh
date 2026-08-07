#!/usr/bin/env bash
#
# Runs on the HOST from scripts/init-profile.sh (devcontainer.json's
# initializeCommand), before the container is created.
#
# Brings up the shared MongoDB from ../../../local-mongo/docker-compose.yml — the
# database this profile's MONGO_URL/MONGO_OPLOG_URL point at (see `env`) — and
# with it the `local-mongo` network, which compose/networks.yml declares
# `external` and compose therefore requires to exist before it will create the
# container at all.
#
# Only the `mongo` service. The same file also defines nats and traefik, which
# belong to running the microservices stack on the host and are not this
# container's business — and traefik publishes host port 3000, the port this
# profile publishes for Meteor (`ports`), so starting the whole file here would
# make every `devbox up` fail on an allocated port.
#
# Idempotent by design: this runs on every create and every start of every
# Rocket.Chat workspace, and all but the first find mongo already up.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$(cd "$here/../../../local-mongo" && pwd)/docker-compose.yml"

log() { printf '\033[1;34m[local-mongo]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[local-mongo] WARNING:\033[0m %s\n' "$1" >&2; }
die() { printf '\033[1;31m[local-mongo] ERROR:\033[0m %s\n' "$1" >&2; exit 1; }

if ! docker info >/dev/null 2>&1; then
	# Nothing to add: without docker there is no container to create either, and
	# the CLI is about to say so in its own words.
	warn "docker is not available — skipping"
	exit 0
fi

# -p is not redundant: COMPOSE_PROJECT_NAME is exported by `devbox` for THIS
# workspace's container, and the env var outranks the `name:` in the compose
# file — without it the mongo stack would be adopted into the devcontainer's
# project and `devbox down` would take the database with it.
compose() { docker compose -p local-mongo -f "$compose_file" "$@"; }

# `up -d` alone would do, but it also re-pulls and recreates on any config drift
# and prints noise on every container start, so check first. The container name
# is the project's, since docker-compose.yml pins no container_name.
#
# The network is half of the check on purpose: a stack started before that file
# named its default network is running perfectly well on `local-mongo_default`,
# and skipping on the container alone would leave the devcontainer's `external:
# local-mongo` unsatisfied — compose would refuse to create it, every time,
# until someone recreated this stack by hand. Falling through to `up` moves it.
if docker network inspect local-mongo >/dev/null 2>&1 &&
	[ "$(docker inspect -f '{{.State.Running}}' local-mongo-mongo-1 2>/dev/null || true)" = "true" ]; then
	log "already running at mongo:27017 (host: 127.0.0.1:27017)"
	exit 0
fi

log "starting the shared MongoDB..."
# Not fatal-with-a-warning like the turbo cache, which is only a build
# accelerator: this profile's server cannot start without a database, and the
# compose error for the missing external network says nothing about how to fix
# it.
compose up -d --wait mongo ||
	die "could not start it — try \`docker compose -f $compose_file up -d mongo\` and read the error"

# The entrypoint runs rs.initiate() a couple of seconds after mongod is up, and
# --wait only waits for the container to be running. Nothing here needs the
# replica set yet (setup.sh's yarn install/build comes first, and takes minutes),
# so this is a note, not a wait loop.
log "ready at mongo:27017 (host: 127.0.0.1:27017) — replica set rs0"
