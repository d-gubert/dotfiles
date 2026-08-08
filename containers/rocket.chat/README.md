# Rocket.Chat devcontainer → observability stack

Wiring that connects a **Rocket.Chat devcontainer** to the local
[observability stack](../observability/) so its metrics land in Prometheus and
Grafana.

Because the Rocket.Chat devcontainer lives in the Rocket.Chat repo (not in these
dotfiles), the piece here is a **drop-in Compose override** you point the
devcontainer at:

- [`.devcontainer/docker-compose.observability.yml`](.devcontainer/docker-compose.observability.yml)
  — joins the `observability` network, enables Rocket.Chat's Prometheus endpoint
  (`:9458`), and sets the OTLP endpoint to the collector.

## How it connects

The observability stack creates a shared Docker network named `observability`.
This override adds Rocket.Chat's `app` service to that network with the alias
`rocketchat`, so:

- Rocket.Chat can push OTLP to `otel-collector:4317`.
- Prometheus scrapes `rocketchat:9458` (the `rocketchat` job in
  [`prometheus.yml`](../observability/prometheus/prometheus.yml)).

No host ports are published for metrics — it's all container-to-container over
the shared network.

## Setup

1. **Start the observability stack first** (it creates the network):

   ```sh
   docker compose -f <dotfiles>/containers/observability/docker-compose.yml up -d
   ```

2. **Make the override available to the devcontainer.** In your Rocket.Chat
   checkout, symlink it into `.devcontainer/` (adjust the path to your dotfiles):

   ```sh
   ln -s <dotfiles>/containers/rocket.chat/.devcontainer/docker-compose.observability.yml \
     .devcontainer/docker-compose.observability.yml
   ```

3. **Reference it from `.devcontainer/devcontainer.json`** by adding it to the
   `dockerComposeFile` array (order matters — the override comes last):

   ```jsonc
   {
     "dockerComposeFile": [
       "docker-compose.yml",
       "docker-compose.observability.yml"
     ]
   }
   ```

   > If you'd rather not edit `devcontainer.json`, you can instead export
   > `COMPOSE_FILE=.devcontainer/docker-compose.yml:.devcontainer/docker-compose.observability.yml`
   > when bringing the devcontainer up from the CLI.

4. **Rebuild / reopen the devcontainer.** Once it's up, confirm in Grafana
   (http://localhost:3001) or Prometheus (http://localhost:9090/targets) that the
   `rocketchat` target is `UP`.

## Notes

- The `app` service name is the Rocket.Chat devcontainer convention; if your
  compose uses a different service name, rename it in the override too.
- Rocket.Chat's Prometheus port is `9458` by default. If you've changed it,
  update the `rocketchat` job in the observability `prometheus.yml`.
