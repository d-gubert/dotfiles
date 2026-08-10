# Observability

One OpenTelemetry Collector, one Prometheus and one Grafana for this machine.
Every source on it reports here — Claude Code on the host, Claude Code in a
devbox container, the Rocket.Chat server in a devbox container, and whatever
comes next.

```
containers/observability/up.sh          # start it
http://127.0.0.1:3030                   # Grafana, no login
http://127.0.0.1:9090                   # Prometheus
```

`up.sh` is idempotent and cheap when the stack is already up, which is why a
devbox profile calls it from its `initialize.sh` on every container start.

## The two ways in

| | |
| --- | --- |
| **push** | The source sends OTLP to the collector, which writes to Prometheus over remote write. `127.0.0.1:4317` (gRPC) or `:4318` (HTTP) from the host; `otel-collector:4317` from a container on the `observability` network. |
| **pull** | Prometheus scrapes a container that exposes `/metrics`. The target list comes from Docker labels — see below. |

Which one a source uses is the source's choice, not ours: Claude Code only
pushes, and Rocket.Chat only exposes an endpoint.

## Adding a source that pushes

Point it at the collector and let it send. For Claude Code that is six
variables. A devbox container gets them from its profile — see
`../devcontainer/projects/rocketchat/env` for the annotated set.

The host's own Claude Code gets the same six from `../../common/.zshrc`, which
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
| `prometheus` | The database, 15d retention. `prometheus/prometheus.yml`. |
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
