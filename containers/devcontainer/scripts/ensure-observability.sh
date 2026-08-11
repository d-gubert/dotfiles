#!/usr/bin/env bash
#
# Runs on the HOST from initialize.sh (devcontainer.json's initializeCommand),
# before the container is created.
#
# Starts the machine's observability stack and puts this container on its
# network. ../../observability/ owns the stack — one OpenTelemetry Collector, one
# Prometheus, one Loki, one Tempo and one Grafana, holding history that outlives
# every workspace. This script only brings it up and contributes the two
# fragments that attach to it.
#
# Neither feature-gated nor profile-gated, unlike nearly everything else that
# contributes a fragment, because two independent things want this one network
# and neither of them owns it:
#
#   the claude-code feature   pushes OTLP to otel-collector:4317
#                             (claude-code/initialize.sh sets the variables)
#   a profile                 exposes /metrics for Prometheus to scrape
#                             (projects/rocketchat/compose/service.yml)
#
# Either could have owned it right up to the moment the other is turned off:
# with the attach in the feature, commenting claude-code out of
# devcontainer.json would silently stop the profile's scrape. A single owner
# also keeps `networks` a single key under services.app — two fragments both
# opening it is a duplicate key and compose rejects the file, which is what the
# service-networks bucket exists to prevent (see lib/overrides.sh).
#
# The cost of not gating it is one bridge network on every container, including
# a workspace that reports nothing. That is cheaper than either coupling above.
#
# Host-side and pre-create for the usual reason: the network is declared
# `external`, and compose refuses to create a container whose external network is
# missing. There is no starting it later from inside.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/lib/overrides.sh"

# Idempotent, cheap when the stack is already up, and deliberately not fatal —
# it runs on every create and every start of every workspace, and a container
# that cannot be created because Grafana would not start is the worse outcome.
# It prints under its own tag.
bash "$(cd "$here/../.." && pwd)/observability/up.sh"

# Attaching. Only what this adds: compose merges a service's `networks` across
# files, so `default` from ../docker-compose.yml stays — and that one carries the
# forwarded ports, so losing it would cost every published port.
echo "- observability" | overrides_add observability service-networks

# Declaring it. External because the stack belongs to the machine, not to any
# workspace: `devbox down` must not take the metrics history with it.
overrides_add observability networks <<-'YAML'
	observability:
	  external: true
	  name: observability
YAML
