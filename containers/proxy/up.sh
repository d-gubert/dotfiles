#!/usr/bin/env bash
#
# Starts the local reverse proxy (./docker-compose.yml) if it is not already
# running.
#
# Runs on the HOST, by hand: `containers/proxy/up.sh`. Nothing calls it
# automatically — the proxy is a convenience, and no workspace needs it to work.
#
# Idempotent, like ../observability/up.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$here/docker-compose.yml"

log() { printf '\033[1;34m[proxy]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[proxy] WARNING:\033[0m %s\n' "$1" >&2; }

if ! docker info >/dev/null 2>&1; then
	warn "docker is not available — skipping"
	exit 0
fi

compose() { docker compose -p proxy -f "$compose_file" "$@"; }

# Every network in the compose file is `external`, and compose refuses to create
# a container whose external network is missing. Say which one and how to fix
# it, rather than let compose print its own version of the same thing.
for network in observability; do
	if ! docker network inspect "$network" >/dev/null 2>&1; then
		warn "the '$network' network does not exist — start that stack first"
		warn "try: $here/../$network/up.sh"
		exit 1
	fi
done

if [ "$(docker inspect -f '{{.State.Running}}' proxy-caddy 2>/dev/null || true)" = "true" ]; then
	log "already running — http://grafana.localhost"
	exit 0
fi

# Port 80 is the one thing here that another program on the machine can take.
# The compose error for it is readable but says nothing about who took it.
if ss -tln 2>/dev/null | grep -qE '[^0-9]:80\s'; then
	warn "something already listens on port 80 — compose is about to fail"
	warn "find it with: sudo ss -tlnp | grep ':80 '"
fi

log "starting the reverse proxy..."
compose up -d --wait

log "ready:"
log "  http://grafana.localhost      (also http://127.0.0.1:3030)"
log "  http://prometheus.localhost   (also http://127.0.0.1:9090)"
log "  http://loki.localhost         (also http://127.0.0.1:3100)"
log "  http://tempo.localhost        (also http://127.0.0.1:3200)"
