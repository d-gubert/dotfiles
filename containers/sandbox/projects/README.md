# Profiles

The sandbox is deliberately generic: a JS toolchain, an egress allowlist and
nothing that belongs to any one repository. A **profile** is how a repository's
own setup reaches it.

One profile is picked per workspace, by matching the workspace's absolute host
path against each `match` file — first match wins, `default` when nothing
matches. Override with `devbox --profile <name> up` or `DEVBOX_PROFILE=<name>`.

Every file is optional. A profile with nothing but a `match` file gets you the
bare toolchain sandbox and a durable scratch directory.

| File | Runs / applies | What it is |
| --- | --- | --- |
| `match` | host, at `up` | Host path globs, one per line. A leading `~/` is expanded. `default` never matches by path. |
| `env` | sandbox | `KEY=VALUE` lines, folded into the kit's `environment.variables`. |
| `env.local` | sandbox | The same, **gitignored** — for a license key or token that has no business in a dotfiles repo. Layered on top of `env`. |
| `ports` | host, at create | `host:sandbox` per line, passed as `sbx create --publish`. A host port the host already uses moves to the next free one, with a warning — so a second workspace of the same profile just works. `DEVBOX_PORTS=3100:3000 devbox up` overrides the file when you want to pin which port it gets. |
| `volumes` | sandbox, at create | `path [size]` per line. Each becomes a kit volume — block storage inside the VM, mounted over that path. For a hot directory that should not sit on the workspace mount: `node_modules`, a build output. Size defaults to `4g`. |
| `allowed-domains` | sandbox, at create | Extra egress allowlist entries. Merged with the base list into the kit's `permissions.network.allow`. |
| `setup.sh` | sandbox, at create | Installs whatever the repo needs, as `agent`, **behind the allowlist**. |
| `initialize.sh` | host, at create | The host-side counterpart of `setup.sh`, for whatever has to exist on this side first — a companion stack the sandbox connects to. See `rocketchat`. |

Everything except `match` and `initialize.sh` is applied by
`../scripts/build-kit.sh`, which writes one kit per workspace and hands it to
`sbx create --kit`.

> **A kit is chosen at create time.** Editing any of these files takes effect on
> `devbox rebuild`, not on a restart. Under the devcontainer the allowlist and
> the environment were re-read on every start; they are not now.

## Writing a `setup.sh`

It runs once, at sandbox create, with `$DEVBOX_WORKSPACE` as its cwd and can
rely on:

| Variable | |
| --- | --- |
| `$DEVBOX_WORKSPACE` | the checkout — the *same* absolute path as on the host |
| `$DEVBOX_TOOLS` | a host directory shared by every workspace on this profile, and the place a toolchain goes so a rebuild does not fetch it again |
| `$DEVBOX_PROFILE` | this profile's name |
| `$DEVBOX_HOME` | this directory's parent, mounted read-only at its host path |

Make it **idempotent**: it re-runs on every create, and everything expensive it
put in `$DEVBOX_TOOLS` is still there from last time.

`sudo` is passwordless, which is what you need for a launcher in
`/usr/local/bin` — and for claiming the mount point of any volume the profile
declares inside the workspace (they arrive `root:root`, see `rocketchat`).

> **It runs behind the allowlist.** This is the one real behaviour change from
> the devcontainer, where `setup.sh` ran before the firewall was applied and so
> could download from anywhere. A sandbox has no unrestricted window: every host
> the install reaches belongs in this profile's `allowed-domains`, and the
> symptom of a missing one is a hung or refused download during `devbox up`.

## Writing an `initialize.sh`

It runs **on the host**, before the sandbox is created, with `$DEVBOX_HOME` set
to this directory's parent *on the host*.

Use it for what has to exist on the host first. A sandbox is a microVM with its
own network namespace and its own Docker daemon, so it cannot join a host Docker
network and cannot resolve a host container by name — what it *can* reach is a
port published on the host, through `host.docker.internal`. `rocketchat` starts
the shared MongoDB this way and points `MONGO_URL` at that name.

It must be **idempotent** — it runs on every create — and it must not fail for a
reason the user can't act on: an error here means no sandbox at all, so check
whether docker is even available and exit cleanly if it isn't.

Put the hosts it makes reachable in `allowed-domains`. `host.docker.internal` is
already in the base list.

> Prometheus does **not** scrape a sandbox. The `devbox` job in
> `containers/observability` discovers containers through the host Docker daemon,
> and a sandbox's containers are not there. Claude Code's telemetry still
> arrives, because it pushes.

## Placeholders

A path inside the workspace or in the shared scratch differs per workspace and
per user, so no checked-in file can name it. Three placeholders are substituted
in `env`, `env.local` and `volumes`:

| | |
| --- | --- |
| `%WORKSPACE%` | the checkout (the same path on the host and in the sandbox) |
| `%TOOLS%` | this profile's durable scratch (= `$DEVBOX_TOOLS`) |
| `%CACHES%` | where the shared caches live (= `$DEVBOX_CACHES`) |

Nothing else is expanded — these files are data, not scripts.
