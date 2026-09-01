#!/usr/bin/env bash
#
# Starts the local observability stack (./docker-compose.yml) if it is not
# already running.
#
# Runs on the HOST, and nothing in a devbox sandbox calls it any more: a sandbox
# is a microVM and cannot join this stack's network, so it pushes OTLP to
# host.docker.internal:4317 instead and needs the stack up in its own right.
#
# Start it by hand — `containers/observability/up.sh` — or leave it to whatever
# else calls it. A profile that depends on it can still call it from its own
# initialize.sh, which runs on the host before the sandbox is created.
#
# Idempotent by design, and all but the first call find the stack already up.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$here/docker-compose.yml"

log() { printf '\033[1;34m[observability]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[observability] WARNING:\033[0m %s\n' "$1" >&2; }

if ! docker info >/dev/null 2>&1; then
	# Nothing to add: without docker there is no stack to start, and the caller
	# is about to say so in its own words.
	warn "docker is not available — skipping"
	exit 0
fi

# -p pins the project name against a COMPOSE_PROJECT_NAME inherited from the
# caller's environment, which outranks the `name:` in the compose file. Without
# it this stack can be adopted into somebody else's project and torn down with
# it, taking the whole metrics history along.
compose() { docker compose -p observability -f "$compose_file" "$@"; }

# `up -d` alone would work, but it re-pulls and recreates on any config drift and
# prints noise on every single container start. Check first.
#
# The network is half of the check on purpose: a caller's `external:
# observability` is unsatisfied while that network is missing, however healthy
# the containers look, and compose would then refuse to create their container
# every time. Falling through to `up` recreates it.
if docker network inspect observability >/dev/null 2>&1 &&
	[ "$(docker inspect -f '{{.State.Running}}' observability-prometheus 2>/dev/null || true)" = "true" ]; then
	log "already running — Grafana at http://127.0.0.1:3030"
	exit 0
fi

log "starting the observability stack..."
# A warning, not a failure: this stack only watches the work, it is not part of
# it. A dev container that cannot be created because Grafana would not start is
# a worse outcome than a container with no dashboards.
#
# The exception is the network, which the caller's compose file genuinely
# depends on — but `up` creates that before any container starts, so a partial
# failure here still leaves the attach working.
if ! compose up -d --wait; then
	warn "the stack did not come up cleanly — metrics may be missing"
	warn "try: docker compose -p observability -f $compose_file up -d  (and read the error)"
	exit 0
fi

log "ready — Grafana at http://127.0.0.1:3030, Prometheus at http://127.0.0.1:9090"
log "OTLP in: 127.0.0.1:4317 (gRPC) / 127.0.0.1:4318 (HTTP), or otel-collector:4317 from a container"
