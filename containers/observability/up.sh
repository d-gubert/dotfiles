#!/usr/bin/env bash
#
# Starts the local observability stack (./docker-compose.yml) if it is not
# already running.
#
# Runs on the HOST. A devbox profile calls it from its own initialize.sh — see
# ../devcontainer/projects/rocketchat/initialize.sh — because the profile
# attaches the container to the `observability` network as *external*, and
# compose refuses to create a container whose external network is missing. There
# is no "start it later, from inside".
#
# Safe to run by hand too: `containers/observability/up.sh`.
#
# Idempotent by design — it runs on every container create and every start of
# every workspace that opts in, and all but the first find the stack already up.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$here/docker-compose.yml"

log() { printf '\033[1;34m[observability]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[observability] WARNING:\033[0m %s\n' "$1" >&2; }

if ! docker info >/dev/null 2>&1; then
	# Nothing to add: without docker there is no container to create either, and
	# the caller is about to say so in its own words.
	warn "docker is not available — skipping"
	exit 0
fi

# -p is not redundant: `devbox` exports COMPOSE_PROJECT_NAME for the workspace's
# own container, and the env var outranks the `name:` in the compose file.
# Without it this stack is adopted into that workspace's project, where `devbox
# down` — which matches by project label — would take the whole metrics history
# down with the workspace.
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
