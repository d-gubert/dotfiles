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
| `ports` | host, at `up` | `host:container` per line. `DEVBOX_PORTS=3100:3000 devbox up` overrides it, which is how a second workspace of the same profile avoids a port clash. |
| `allowed-domains` | container, every start | Extra egress allowlist entries — hostnames or CIDRs. Merged with the base list and each declared feature's. Takes effect on a **restart**, no rebuild. |
| `setup.sh` | container, at create | Installs whatever the repo needs, as `vscode`, with the network still **unrestricted** (`updateContentCommand` runs before the firewall). |
| `compose/*.yml` | host, at `up` | Raw compose fragments for anything the above can't say. One file per override bucket: `service.yml`, `service-environment.yml`, `service-volumes.yml`, `volumes.yml`. |

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
