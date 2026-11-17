#!/usr/bin/env bash
#
# Runs on the HOST from ../../scripts/build-kit.sh, before the sandbox is
# created.
#
# Brings up the shared MongoDB this profile's sandbox talks to:
#
#   local-mongo     ../../../local-mongo/docker-compose.yml, the database this
#                   profile's MONGO_URL points at (see `env`).
#
# It runs on the host, and the database runs on the host, because a sandbox
# cannot reach a host Docker network — the sandbox connects to the published
# port through host.docker.internal instead. See the MONGO_URL note in `env` for
# what that costs.
#
# The observability stack is not started here. Claude Code pushes to it from
# every sandbox whatever the profile, so ../../../observability/up.sh is the
# machine's business rather than this profile's.
#
# Only the `mongo` service. The same file also defines nats and traefik, which
# belong to running the microservices stack on the host and are not this
# sandbox's business — and traefik publishes host port 3000, the port this
# profile publishes for Meteor (`ports`), so starting the whole file here would
# make every `devbox up` fail on an allocated port.
#
# Idempotent by design: this runs on every create of every Rocket.Chat
# workspace, and all but the first find mongo already up.
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

# -p pins the project name against a COMPOSE_PROJECT_NAME inherited from the
# environment, which outranks the `name:` in the compose file. Without it the
# mongo stack can be adopted into somebody else's project and torn down with it,
# taking the database along.
compose() { docker compose -p local-mongo -f "$compose_file" "$@"; }

ensure_mongo() {
	# `up -d` alone would do, but it also re-pulls and recreates on any config
	# drift and prints noise on every container start, so check first. The
	# container name is the project's, since docker-compose.yml pins no
	# container_name.
	#
	# The network is half of the check on purpose: a stack started before that
	# file named its default network is running perfectly well on
	# `local-mongo_default`, and skipping on the container alone would leave that
	# older shape in place forever. Falling through to `up` moves it. Nothing in
	# the sandbox depends on the network's name any more — it connects to the
	# published port — but anything on the host daemon that attaches as
	# `external: local-mongo` still does.
	if docker network inspect local-mongo >/dev/null 2>&1 &&
		[ "$(docker inspect -f '{{.State.Running}}' local-mongo-mongo-1 2>/dev/null || true)" = "true" ]; then
		log "already running at mongo:27017 (host: 127.0.0.1:27017)"
		return 0
	fi

	log "starting the shared MongoDB..."
	# Not fatal-with-a-warning like the turbo cache, which is only a build
	# accelerator: this profile's server cannot start without a database, and the
	# compose error for the missing external network says nothing about how to fix
	# it.
	compose up -d --wait mongo ||
		die "could not start it — try \`docker compose -f $compose_file up -d mongo\` and read the error"

	# The entrypoint runs rs.initiate() a couple of seconds after mongod is up,
	# and --wait only waits for the container to be running. Nothing here needs
	# the replica set yet (setup.sh's yarn install/build comes first, and takes
	# minutes), so this is a note, not a wait loop.
	log "ready at 127.0.0.1:27017 on the host — the sandbox reaches it at host.docker.internal:27017"
}

ensure_mongo
