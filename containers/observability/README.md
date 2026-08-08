# Observability stack

A local OpenTelemetry + Prometheus + Grafana stack for collecting metrics from
several sources on your machine. Ships wired up for two starter sources —
**Claude Code** and **Rocket.Chat** — and is easy to extend.

```
                 OTLP 4317/4318                     scrape
 Claude Code ───────────────────▶ ┌───────────────┐  8889   ┌────────────┐
 (host)                           │ otel-collector │◀────────│ Prometheus │
                                  └───────────────┘         └─────┬──────┘
 Rocket.Chat ─────────────────────── scrape :9458 ────────────────┤
 (devcontainer)                                                    │
                                                             ┌─────▼──────┐
                                                             │  Grafana   │
                                                             └────────────┘
```

- **OTel Collector** — single OTLP ingestion point (`4317` gRPC, `4318` HTTP).
  Re-exports received metrics on `:8889` for Prometheus.
- **Prometheus** — scrapes the collector and any Prometheus-native source
  (e.g. Rocket.Chat on `:9458`).
- **Grafana** — pre-provisioned with the Prometheus datasource and an
  "Observability Overview" dashboard.

## Ports

| Service    | URL / endpoint          | Notes                                  |
| ---------- | ----------------------- | -------------------------------------- |
| Grafana    | http://localhost:3001   | `admin` / `admin` (change via `.env`)  |
| Prometheus | http://localhost:9090   |                                        |
| OTLP gRPC  | `localhost:4317`        | host processes push here               |
| OTLP HTTP  | `localhost:4318`        |                                        |

Grafana is on host port **3001** to stay clear of Rocket.Chat's **3000**.

## Usage

```sh
cp .env.example .env          # optional: pin versions / change Grafana creds
docker compose up -d
```

Bring this stack up **first** — it creates the shared `observability` Docker
network that other Compose projects (like the Rocket.Chat devcontainer) join.

Tear down (keeps volumes):

```sh
docker compose down
```

## Sources

### Claude Code (host)

Claude Code emits OTLP metrics/logs when telemetry is enabled. The dotfiles
`.zshrc` has an opt-in block — enable it by exporting the toggle before starting
your shell (e.g. in `~/.zshrc.local`):

```sh
export DOTFILES_CLAUDE_TELEMETRY=1
```

That sets `CLAUDE_CODE_ENABLE_TELEMETRY=1` and points the OTLP exporter at
`http://localhost:4317`. Restart Claude Code and its metrics show up under the
`otel-collector` job in Prometheus (metric names prefixed `claude_code_`).

### Rocket.Chat (devcontainer)

See [`../rocket.chat`](../rocket.chat/) for a drop-in devcontainer Compose
override that joins this network and enables Rocket.Chat's Prometheus endpoint,
scraped as the `rocketchat` job.

## Adding another source

- **Push (OTLP):** point the app's OTLP exporter at `localhost:4317` (host) or
  `otel-collector:4317` (if it shares the `observability` network).
- **Pull (Prometheus):** add a `scrape_config` job to
  [`prometheus/prometheus.yml`](prometheus/prometheus.yml) and reload with
  `curl -X POST http://localhost:9090/-/reload`.
