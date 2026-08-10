# Profiles

The container is deliberately generic: a JS toolchain, an egress firewall and
nothing that belongs to any one repository. A **profile** is how a repository's
own setup reaches it.

One profile is picked per workspace, by matching the workspace's absolute host
path against each `match` file — first match wins, `default` when nothing
matches. Override with `devbox --profile <name> up` or `DEVBOX_PROFILE=<name>`.

Every file is optional. A profile with nothing but a `match` file gets you the
bare toolchain container and a durable scratch volume.

| File | Runs / applies | What it is |
| --- | --- | --- |
| `match` | host, at `up` | Host path globs, one per line. A leading `~/` is expanded. `default` never matches by path. |
| `env` | container | `KEY=VALUE` lines, injected as the service's environment. |
| `env.local` | container | The same, **gitignored** — for a license key or token that has no business in a dotfiles repo. Layered on top of `env`. |
| `ports` | host, at `up` | `host:container` per line. A host port the host already uses moves to the next free one, with a warning — so a second workspace of the same profile just works. `DEVBOX_PORTS=3100:3000 devbox up` overrides the file when you want to pin which port it gets. |
| `allowed-domains` | container, every start | Extra egress allowlist entries — hostnames or CIDRs. Merged with the base list and each declared feature's. Takes effect on a **restart**, no rebuild. |
| `setup.sh` | container, at create | Installs whatever the repo needs, as `vscode`, with the network still **unrestricted** (`updateContentCommand` runs before the firewall). |
| `initialize.sh` | host, at `up` | The host-side counterpart of `setup.sh`, for whatever the fragments below *assume* and compose won't create: an external network, a companion stack. See `rocketchat`. |
| `compose/*.yml` | host, at `up` | Raw compose fragments for anything the above can't say. One file per override bucket: `service.yml`, `service-environment.yml`, `service-volumes.yml`, `volumes.yml`, `networks.yml`. |

## Writing a `setup.sh`

It runs with `$DEVBOX_WORKSPACE` as its cwd and can rely on:

| Variable | |
| --- | --- |
| `$DEVBOX_WORKSPACE` | the checkout, inside the container |
| `$DEVBOX_TOOLS` | `~/.devbox` — a volume shared by every workspace on this profile, and the only writable place that survives a rebuild. Toolchains go here. |
| `$DEVBOX_PROFILE` | this profile's name |
| `$DEVBOX_HOME` | `/opt/devbox`, this directory's parent, read-only |

Make it **idempotent**: it re-runs on every create and rebuild, and everything
expensive it puts in `$DEVBOX_TOOLS` is still there from last time.

`sudo` is passwordless, which is what you need for a launcher in
`/usr/local/bin` — and for claiming the mount point of any volume the profile
mounts inside the workspace (they arrive `root:root`, see `rocketchat`).

## Writing an `initialize.sh`

It runs **on the host**, last of the profile's host-side steps, with the same
environment as `scripts/initialize.sh` — note that `$DEVBOX_HOME` is this
directory's parent *on the host* here, not `/opt/devbox`.

Use it for what has to exist before the container is *created*, which is
anything a fragment declares `external`: compose refuses to create a container
whose external network or volume is missing, so there is no starting it later
from inside. `rocketchat` brings up the shared MongoDB this way.

It must be **idempotent** — it runs on every create and every start — and it
must not fail for a reason the user can't act on: an error here means no
container at all, so check whether docker is even available and exit cleanly if
it isn't.

Reaching a service it starts takes two more things: `compose/networks.yml` to
declare that stack's network `external`, and `compose/service.yml` to attach to
it. The firewall needs nothing — it accepts every network the container is
attached to, in both directions — but put the CIDR in `allowed-domains` anyway,
as the record of what this profile talks to.

`rocketchat` does this twice: the shared MongoDB, and the observability stack
in `containers/observability`. The second one also shows how a profile gets its
own metrics scraped — three `devbox.metrics.*` labels in `compose/service.yml`
and nothing else.

## Placeholders in `compose/*.yml`

A mount target inside the workspace has to name the container's workspace path,
which differs per workspace. Three placeholders are substituted when the
fragment is merged:

| | |
| --- | --- |
| `%WORKSPACE%` | the workspace path inside the container |
| `%TOOLS%` | `/home/vscode/.devbox` |
| `%PROFILE%` | the profile's name |

Nothing else is expanded — a fragment is data, not a script.
