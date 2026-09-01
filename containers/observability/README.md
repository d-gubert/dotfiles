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

`../proxy` serves the same four under names — `http://grafana.localhost` and so
on — if it is up. It is optional and the ports above never stop working.

`up.sh` is idempotent and cheap when the stack is already up, which is why
devbox calls it from `../devcontainer/scripts/ensure-observability.sh` on every
container create and start.

## The two ways in

| | |
| --- | --- |
| **push** | The source sends OTLP to the collector, which splits it by signal: metrics to Prometheus over remote write, logs to Loki, spans to Tempo. `127.0.0.1:4317` (gRPC) or `:4318` (HTTP) from the host; `otel-collector:4317` from a container on the `observability` network. One connection carries all three. |
| **pull** | Prometheus scrapes a container that exposes `/metrics`. The target list comes from Docker labels — see below. |

Which one a source uses is the source's choice, not ours: Claude Code only
pushes, and Rocket.Chat only exposes an endpoint.

## Adding a source that pushes

Point it at the collector and let it send. For Claude Code that is nine
variables. A devbox container gets them from the `claude-code` feature, not from
its profile — see `../devcontainer/scripts/claude-code/initialize.sh` for the
annotated set. Every workspace that runs Claude Code therefore reports, whatever
repository it is.

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

**`workspace` is set twice on the host, and the second one is the useful one.**
The export says `workspace=host`, which is enough to tell the host apart from a
container and nothing more — it put 133 of 153 sessions and 80% of the spend in
a single unlabelled bucket, while the devbox worktrees, a sixth of the work, were
the only part of the dashboard that said where a session ran.

An exported variable cannot do better. It runs once, at shell start, long before
you pick a directory. So `.zshrc` also defines a `claude` shell function that
reads the git root at LAUNCH time and rewrites the attribute for that one
process, giving `workspace=host:dotfiles`, `workspace=host:RocketChat` and so on.
The git root and not `$PWD`, because `$PWD` would open a new time series for
every subdirectory you stood in; the root bounds the cardinality to repositories.
The exported default stays as the fallback for a `claude` that does not come
through the function.

Two consequences worth knowing. Series written before this keep the bare `host`
value, so both appear until the old ones age out. And a repository whose
directory name contains a comma or an equals sign would break the attribute
list — the function replaces both with a dash rather than trusting that it never
happens.

`OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` is worth keeping.
Claude Code defaults to delta temporality and Prometheus counters are cumulative;
the collector converts, so delta senders do work — but the sender's own running
total survives a collector restart and a reconstructed one does not.

## Adding a source that is scraped

Attach the container to the `observability` network and give it these labels. A
devbox container is attached already, by
`../devcontainer/scripts/ensure-observability.sh`, so there the labels are the
whole job:

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
for you to approve something. It fires on every permission gate, not only the
ones you saw: an auto-granted gate closes in about 15ms where one you answered
takes seconds, so the duration is what tells them apart. Nothing else in the
stack can — an auto-mode grant and a `settings.json` allowlist grant write the
same `source=config` on the `tool_decision` event.

**Spans are countable, not only readable.** `metrics_generator` in `tempo/tempo.yml`
runs the `local-blocks` processor, which keeps the spans queryable in place. Without
it every TraceQL metrics query — anything with `| rate()` or `| quantile_over_time()`
— answers `error finding generators: empty ring`, while plain search keeps working.
That split is why the gap survives a long time before anyone notices: traces read
fine and only a dashboard panel fails.

Two settings in that block are load-bearing and one of them is not the default:

| | |
| --- | --- |
| `filter_server_spans: false` | **Required.** Left at its `true` default the processor keeps SERVER spans only, and Claude Code emits none — `interaction`, `llm_request` and `tool` are all INTERNAL. The generator then reports spans received and stores nothing, and every metrics query answers with an empty series rather than an error. |
| `flush_to_storage: true` | Writes the processor's blocks to the same local path as the rest, so a query can reach past the few minutes still in memory. |

Counting starts when the generator does. Spans ingested before it was enabled are
still searchable and still readable; they are not in its blocks, so a metrics
panel over them is empty. The root `claude_code.interaction` span also arrives
late by design — it closes when the prompt does, so a long prompt reaches the
generator minutes after its children.

**Loki's query length limit is off, because the default contradicts the retention.**
`max_query_length` defaults to `30d1h`, and Loki measures a query's length as the
dashboard range PLUS the range vector inside it. A `count_over_time(... [$__range])`
over a 30 day dashboard is therefore measured as 60 days and rejected — which is
the exact shape of every month-over-month panel in
`grafana/dashboards/claude-code.json`. `limits_config.max_query_length: 0` in
`loki/loki.yml` removes the ceiling, matching the "keep everything" choice the
other three stores already make.

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
