#!/usr/bin/env bash
#
# Runs on the HOST from scripts/initialize.sh, before the container is created,
# and only when devcontainer.json declares the claude-code feature (feature.id).
#
# The host-side entry point for everything the claude-code feature needs: the
# compose fragment (shared config volume, the staged host config, and the
# capabilities the egress firewall requires), the volume itself, and the skills
# and CLAUDE.md staged out of your host config for the container to pick up.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$here/../lib/overrides.sh"

# Required by init-firewall.sh (post-start.sh) to manage iptables/ipset inside
# the container. Contributed by the feature that needs them rather than granted
# unconditionally in docker-compose.yml: NET_ADMIN is most of what a container
# needs to rewrite its own networking, and without Claude Code there is nothing
# in here asking for it.
overrides_add claude-code service <<-'YAML'
	cap_add:
	  - NET_ADMIN
	  - NET_RAW
YAML

# Claude Code's config dir — auth, settings, history, installed skills — shared by
# every workspace, so one login covers all of them. External with a fixed name is
# what makes that work; see gh/initialize.sh for the long version of why an
# ordinary volume (or a devcontainer.json `mounts` entry, which becomes one) would
# be namespaced per workspace instead.
#
# No subpath, unlike gh's two-in-one volume: this one carries a single mount, so
# the root simply *is* ~/.claude. ensure-claude-config.sh still has to run on the
# host, because the root has to arrive owned by the container user and compose
# has no chown.
# Unquoted heredoc, unlike the others: $DEVBOX_STATE has to expand.
overrides_add claude-code service-volumes <<-YAML
	- type: volume
	  source: claude-config
	  target: /home/vscode/.claude
	# Your host skills and CLAUDE.md, dereferenced and copied out by
	# stage-host-config.sh below. Read-only and outside the workspace:
	# install-host-config.sh copies from here into the config volume on every
	# start, and nothing in the container can write back towards your host config.
	- type: bind
	  source: ${DEVBOX_STATE:?}/host-config
	  target: /opt/devbox-host-config
	  read_only: true
YAML

overrides_add claude-code volumes <<-'YAML'
	claude-config:
	  external: true
	  name: devbox-claude-config
YAML

# --- Telemetry ----------------------------------------------------------------
#
# Claude Code's metrics, events and spans, pushed to the machine's observability
# stack (../../../observability/). `otel-collector` resolves because
# ../ensure-observability.sh attaches every container to that network; the host's
# own Claude Code sends to 127.0.0.1:4317 instead, out of common/.zshrc.
#
# Owned by the feature and not by a profile: none of it is repo-specific, and
# Claude Code runs in every container that declares the feature. Comment the
# feature out of devcontainer.json and the telemetry goes with it, which is the
# same rule as the volume and the capabilities above.
#
# Unquoted heredoc: the two resource attributes at the bottom have to expand.
# Nothing here contains a literal `$`, which compose would interpolate.
#
# https://code.claude.com/docs/en/monitoring-usage
overrides_add claude-code service-environment <<-YAML
	CLAUDE_CODE_ENABLE_TELEMETRY: "1"
	OTEL_METRICS_EXPORTER: "otlp"
	# The event records — one per prompt, tool call and API request — which the
	# collector routes to Loki. Off by default in Claude Code, and without it the
	# metrics counters are all this stack ever sees.
	#
	# What the events CONTAIN is a separate set of switches, all off:
	# OTEL_LOG_USER_PROMPTS, OTEL_LOG_ASSISTANT_RESPONSES, OTEL_LOG_TOOL_DETAILS
	# and OTEL_LOG_RAW_API_BODIES. Left off, an event says a prompt happened and
	# how big it was; turned on, it carries the text.
	OTEL_LOGS_EXPORTER: "otlp"
	OTEL_LOG_TOOL_DETAILS: "1"
	# Spans, which the collector routes to Tempo: one \`claude_code.interaction\`
	# per prompt, with the API calls and tool calls nested under it. Two variables
	# and not one — the exporter alone does nothing while the beta flag is off,
	# and the flag alone produces spans that go nowhere.
	#
	# Redaction is separate again, and shares the OTEL_LOG_* switches above: off,
	# a span still carries tool_name, model, token counts and every duration. What
	# it drops is the prompt text, the command string and the file path.
	CLAUDE_CODE_ENHANCED_TELEMETRY_BETA: "1"
	OTEL_TRACES_EXPORTER: "otlp"
	OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
	OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
	# Claude Code defaults to delta temporality; Prometheus counters are
	# cumulative. The collector converts either way (its deltatocumulative
	# processor), so this is not what makes the metrics arrive — it is that the
	# sender's own running total survives a collector restart and a reconstructed
	# one does not.
	OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE: "cumulative"
	# Every 20s rather than the default 60s: a dev session is short, and waiting a
	# minute to see whether the pipe works at all is most of the debugging time.
	OTEL_METRIC_EXPORT_INTERVAL: "10000"
	# Rides along on everything Claude Code exports, so these two arrive as labels
	# in Prometheus and a panel can break cost or tokens down by checkout instead
	# of totalling every worktree of a repo into one line. Built here rather than
	# in a profile's compose fragment, which is where the workspace path used to
	# come from: the values are the same for any profile, and scripts/initialize.sh
	# exports both.
	#
	# Comma-separated key=value, so neither value may contain a comma or an equals
	# sign — a workspace path and a profile name contain neither.
	OTEL_RESOURCE_ATTRIBUTES: "workspace=${DEVBOX_CONTAINER_WORKSPACE:?},devbox.profile=${DEVBOX_PROFILE:?}"
YAML

bash "$here/ensure-claude-config.sh"

bash "$here/stage-host-config.sh"
