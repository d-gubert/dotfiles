# Observability

One OpenTelemetry Collector, one Prometheus, one Loki, one Tempo and one Grafana
for this machine. Every source on it reports here — Claude Code on the host,
Claude Code in a devbox container, the Rocket.Chat server in a devbox container,
and whatever comes next.

```
containers/observability/up.sh          # start it
http://127.0.0.1:3030                   # Grafana, no login
http://127.0.0.1:9090                   # Prometheus
http://127.0.0.1:3100                   # Loki
http://127.0.0.1:3200                   # Tempo
```

`up.sh` is idempotent and cheap when the stack is already up, which is why a
devbox profile calls it from its `initialize.sh` on every container start.

## The two ways in

| | |
| --- | --- |
| **push** | The source sends OTLP to the collector, which splits it by signal: metrics to Prometheus over remote write, logs to Loki, spans to Tempo. `127.0.0.1:4317` (gRPC) or `:4318` (HTTP) from the host; `otel-collector:4317` from a container on the `observability` network. One connection carries all three. |
| **pull** | Prometheus scrapes a container that exposes `/metrics`. The target list comes from Docker labels — see below. |

Which one a source uses is the source's choice, not ours: Claude Code only
pushes, and Rocket.Chat only exposes an endpoint.

## Adding a source that pushes

Point it at the collector and let it send. For Claude Code that is nine
variables. A devbox container gets them from its profile — see
`../devcontainer/projects/rocketchat/env` for the annotated set.

The host's own Claude Code gets the same nine from `../../common/.zshrc`, which
exports them only when `claude` is installed and the collector answers on
`127.0.0.1:4317`. `~/.claude/settings.json` would work too, but it is a personal
file that this repo does not stow, and it has no way to ask whether the stack is
up: a `claude` pointed at a dead collector retries every export interval and logs
each failure.

The cost of the shell over the settings file: a shell that was already open when
the stack came up has no variables. Open a new one.

`127.0.0.1:4317` and not `otel-collector:4317`: the host reaches the collector
through the published port, a container reaches it by name over the network.

`OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` is worth keeping.
Claude Code defaults to delta temporality and Prometheus counters are cumulative;
the collector converts, so delta senders do work — but the sender's own running
total survives a collector restart and a reconstructed one does not.

## Adding a source that is scraped

Attach the container to the `observability` network and give it these labels:

| Label | |
| --- | --- |
| `devbox.metrics.port` | **required** — the port `/metrics` listens on inside the container. Its presence is what makes the container a target. |
| `devbox.metrics.job` | the `job` label. Defaults to the container name. |
| `devbox.metrics.path` | the metrics path. Defaults to `/metrics`. |
| `devbox.workspace` | for a devbox container, which checkout it is. Becomes a `workspace` label. |

`../devcontainer/projects/rocketchat/compose/service.yml` is the worked example.
Nothing has to be published to the host and nothing has to be added here:
discovery picks the container up within `refresh_interval` of it starting, and
drops it when it stops.

`instance` is the container name, so two worktrees of one repo are two instances
of one job rather than a single flapping target.

## What runs

| Service | |
| --- | --- |
| `otel-collector` | The push door, and the delta-to-cumulative conversion that lets any OTLP source work. `otel-collector/config.yaml`. |
| `prometheus` | The metrics database, no retention limit. `prometheus/prometheus.yml`. |
| `loki` | The log database, no retention limit. `loki/loki.yml`. |
| `tempo` | The trace database, no retention limit. `tempo/tempo.yml`. |
| `grafana` | The front end, anonymous Admin. Datasource and dashboards provisioned from `grafana/`. |
| `docker-socket-proxy` | A read-only, two-endpoint window onto the Docker API, so Prometheus can discover targets without a socket mount. |

The dashboards under `grafana/dashboards/` are files first: the provisioning
provider sets `allowUiUpdates: false`, so an edit in the browser cannot be saved
over them and what is deployed never drifts from what is in this repo. Use "Save
as" to keep an experiment.

## Notes

**Metric names carry no unit or `_total` suffix.** The collector sets
`add_metric_suffixes: false`, so `claude_code.cost.usage` arrives as
`claude_code_cost_usage` and not `claude_code_cost_usage_USD`. Dots become
underscores; nothing else changes. It costs the Prometheus naming convention and
buys queries that do not depend on a unit string the sender picked.

**Claude Code's events arrive empty of content, on purpose.** `OTEL_LOGS_EXPORTER`
turns the event stream on; four further switches decide what each event carries,
and all four are off:

| | |
| --- | --- |
| `OTEL_LOG_USER_PROMPTS` | the prompt text |
| `OTEL_LOG_ASSISTANT_RESPONSES` | the response text |
| `OTEL_LOG_TOOL_DETAILS` | tool parameters, commands, MCP server and tool names |
| `OTEL_LOG_RAW_API_BODIES` | the full request and response JSON |

Off, an event records that a prompt happened, its size and its timing — enough to
follow a session's shape. On, it records what was said. Everything stays on this
machine either way; the question is only whether a log store keeps a copy of the
work forever. Set them in the same two files as the rest.

**Traces need two variables, not one.** `OTEL_TRACES_EXPORTER=otlp` alone does
nothing while `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` is off, and the flag alone
produces spans that go nowhere. Both are set in the same two files as the rest.
Beta, so the span names and attributes below can change under a Claude Code
upgrade.

One trace per prompt, and this is its shape:

```
claude_code.interaction              the prompt
├── claude_code.llm_request          an API call — model, tokens, ttft_ms, stop_reason
└── claude_code.tool                 a tool call — tool_name, duration_ms, result_tokens
    ├── claude_code.tool.blocked_on_user    how long the permission prompt waited, and the decision
    └── claude_code.tool.execution          the tool body
```

Read them in Grafana's Explore, on the Tempo datasource. The redaction switches
above apply here too: off, a span still carries the model, the token counts, the
tool name and every duration — it drops the prompt text, the command string and
the file path. `OTEL_LOG_TOOL_CONTENT` is a third one that only spans have; it
puts tool input and output in span events.

The `blocked_on_user` span is the one that pays for the rest. It is the only
place in this stack that separates the time Claude worked from the time it waited
for you to approve something.

**Editing a config file needs a container recreate, not a reload.** Each config
is bind-mounted as a single file, and an editor that writes a new file replaces
the inode — the container keeps reading the old one, and
`curl -XPOST localhost:9090/-/reload` cheerfully reloads the stale copy. Use:

```sh
docker compose -p observability -f docker-compose.yml up -d --force-recreate prometheus
```

**The stack is loopback-only.** Every published port binds `127.0.0.1`. Nothing
here has authentication and nothing here should be reachable from the LAN.

**Wiping it.** `docker compose -p observability down -v` takes the metrics
history and Grafana's own database with it. The dashboards come back from the
files.
