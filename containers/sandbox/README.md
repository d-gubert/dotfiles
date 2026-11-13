# devbox — a dev sandbox for whatever you're working on

A network-isolated **microVM** that wraps any checkout on this machine. The
definition lives here, in the dotfiles; the source code comes from your pwd:

```bash
cd ~/dev/RocketChat/worktrees/main
devbox up          # create/start a sandbox with this checkout mounted
devbox claude      # Claude Code, behind the allowlist
devbox shell       # zsh in there
```

Nothing is added to the repository you are working on — no `.devcontainer/`, no
committed compose file. One template image, one set of shared caches and logins,
one allowlist, for every checkout.

The backend is [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`),
which boots each workspace into its own microVM: its own kernel, its own Docker
daemon, its own network namespace, and an egress proxy outside the VM enforcing
what it may reach.

Prerequisites: `sbx` (`sudo apt-get install docker-sbx`, then `sbx login`) and
Docker Engine, which is what builds the template image. `devbox` is
`dotfiles/scripts/devbox`, on `$PATH` through `$DOTFILES_SCRIPTS`.

One thing to do once per machine, before trusting any of this:

```bash
sbx policy init deny-all
```

## The command

| | |
| --- | --- |
| `devbox up` | Create/start the sandbox for this workspace |
| `devbox shell [cmd]` | A shell inside it (zsh) |
| `devbox exec CMD...` | Run one command inside it |
| `devbox claude [args]` | Attach Claude Code to it |
| `devbox stop` | Stop it, keep everything |
| `devbox down` | Delete it — **and its Claude sessions and GitNexus index** |
| `devbox rebuild [--no-cache]` | Recreate it, re-running create-time setup |
| `devbox template [--no-cache]` | Build the template image and load it into `sbx` |
| `devbox status` / `env` | What's running and what egress it has / everything resolved for this pwd |

`--profile <name>` forces a profile, `--workspace <path>` works on a directory
other than the pwd. `shell`, `exec` and `claude` start the sandbox if it isn't
running.

## How one definition serves every checkout

`devbox` derives everything from your pwd and passes it to `sbx create`:

| | |
| --- | --- |
| `DEVBOX_SANDBOX` | `devbox-<dirname>-<hash of the full path>` — the sbx sandbox name, so two checkouts never share one |
| `DEVBOX_WORKSPACE` | The checkout. **The same absolute path inside the sandbox**: sbx mounts every workspace where it lives on the host |
| `DEVBOX_PROFILE` | The `projects/<name>` profile whose `match` claims this path |
| `DEVBOX_STATE` | `~/.local/state/devbox/<sandbox>/` — the generated kit |
| `DEVBOX_CACHES` | `~/.cache/devbox/` — the caches every workspace shares |
| `DEVBOX_TOOLS` | `~/.local/share/devbox/tools/<profile>/` — this profile's durable scratch |

Nothing is stored: run any subcommand from the same directory and it resolves to
the same sandbox.

Same-path mounting is what makes the wiring so short. There is no
`/workspaces/<slug>` remapping, so `TURBO_CACHE_DIR` and friends are just the
host paths; tools that key state by absolute path (Claude Code's
`~/.claude/projects/`) get a distinct entry per checkout for free; and a linked
worktree's `gitdir:` pointer resolves without rewriting anything.

This directory is mounted **read-only at its own host path**, which is how the
scripts and the profiles get in there without living in your repo. Editing one
takes effect on a `devbox rebuild`; only the `Dockerfile` needs
`devbox template`.

## The two artifacts

Everything sbx needs comes in two pieces, and knowing which is which explains
most of this directory.

**The template** is the OCI image the VM boots from: the base OS and the generic
toolchain. `Dockerfile` builds it, `devbox template` loads it:

```
docker build  ->  docker save  ->  sbx template load  ->  sbx create -t devbox:latest
```

It is built `FROM docker/sandbox-templates:claude-code-docker` on purpose.
`sbx create claude` applies the built-in `claude` kit whatever `-t` says, and
that kit expects the `claude` binary on `PATH` and the user to be `agent`
(uid 1000, `/home/agent`, passwordless sudo). Building from Docker's own template
satisfies both.

**The kit** is a YAML artifact applied at create: the egress allowlist, the
environment, the credentials, the install commands, the volumes.
`scripts/build-kit.sh` generates one per workspace into `$DEVBOX_STATE/kit/` and
`devbox` passes it as `--kit`. sbx merges it with the built-in `claude` kit —
allow lists union, environments merge, setup commands concatenate.

That merge is what the generated `docker-compose.overrides.yml` used to do by
hand, and it is why twelve host-side hook scripts collapsed into one generator.

> **A kit is chosen at create time.** Under the devcontainer, the allowlist and
> the staged config were re-read on every start, so a change cost a restart. Here
> it costs `devbox rebuild`.

## Network isolation

Egress is **default-deny plus an allowlist**, enforced by the sandbox runtime's
proxy — outside the VM, so nothing inside can reach around it. That is what makes
`claude` defensible here: no permission prompt reviews a tool call, but the call
runs as a non-root user in a VM that can only reach the list.

It is only default-deny if the *machine's* global policy is. A kit's rules are
added on top of the global policy, so under `allow-all` or `balanced` the sandbox
reaches more than the list:

```bash
sbx policy init deny-all      # once per machine
devbox status                 # what this sandbox may actually reach
```

`devbox` warns on every create when it cannot see `deny-all`.

The allowlist is data, assembled by `scripts/build-kit.sh` from three places
(plus the built-in `claude` kit's own list, which covers Anthropic's hosts):

| | |
| --- | --- |
| `allowed-domains` | The floor: GitHub, the npm/yarn registries, Playwright's CDN, the host |
| `projects/<profile>/allowed-domains` | Merged for workspaces on that profile |
| `DEVBOX_ALLOW_DOMAINS="a.example b.example"` | One-off, at `devbox up` time |

An entry is an exact host (port 443 assumed), a `host:port`, a single-label
`*.example.com` wildcard, or a CIDR. sbx enforces the first three today.

What the sandbox does **not** bound is the workspace: it is mounted read-write,
so anything Claude writes lands in your host checkout. Use it on repositories you
trust.

What it *does* bound, which the container did not: the host's Docker daemon, the
host's networks, and every other checkout on the machine. A sandbox has its own
kernel and its own daemon, and the only paths it can see are the ones `devbox`
passed to `sbx create`.

## Logins

Two, both stored on the **host** and shared by every sandbox.

**Anthropic** is the built-in `claude` kit's: run `devbox claude` and follow the
browser prompt, or store a key with `sbx secret set anthropic`. The OAuth token
is held by the host and injected at the proxy, so it never lands in a file inside
the VM.

**GitHub** is the same mechanism, declared by the generated kit as a `github`
credential that populates `GH_TOKEN` and injects an `Authorization` header for
the five GitHub hosts. Seed it from your host login:

```bash
sbx secret set github --command 'gh auth token'
```

There is no shared `~/.ssh` any more, and so no git-over-SSH: the old
`devbox-gh-auth` volume carried a private key into the container, and the
credential-proxy route carries nothing. Use HTTPS remotes in a sandbox.

## Profiles

The image is deliberately generic — a Node/Yarn/pnpm toolchain through Volta and
nothing that belongs to any one repository. A **profile** is how a repo's own
setup reaches it. One is picked per workspace by matching your path against each
`projects/<name>/match`.

```
projects/rocketchat/
  match              ~/dev/RocketChat/worktrees/*
  env                METEOR_WAREHOUSE_DIR=%TOOLS%/meteor, MONGO_URL=...
  env.local          gitignored — a license key
  ports              3000:3000
  volumes            node_modules and .meteor/local, off the workspace mount
  allowed-domains    the Meteor and Deno download hosts
  setup.sh           pinned Meteor + Deno into $DEVBOX_TOOLS, then yarn install/build
  initialize.sh      host-side; brings up the shared MongoDB before create
```

Every file is optional; `default` is the fallback and is empty on purpose. See
[`projects/README.md`](projects/README.md) for the full contract.

The one behaviour change to know: **`setup.sh` now runs behind the allowlist**.
It used to run at `updateContentCommand`, before the firewall was applied, so it
could download from anywhere. A sandbox has no unrestricted window, so every host
a profile's install reaches belongs in its `allowed-domains`.

## Structure

| File | Purpose |
| --- | --- |
| `Dockerfile` | The template image: base image and the generic toolchain |
| `allowed-domains` | The base egress allowlist |
| `projects/` | Per-repository profiles ([contract](projects/README.md)) |
| `scripts/build-kit.sh` | Generates the per-workspace kit — the allowlist, the environment, the credentials, the volumes, the setup commands |
| `scripts/build-template.sh` | Builds the `Dockerfile` and loads it into the sbx runtime |
| `scripts/ensure-caches.sh` | Creates the shared cache directories and names them for mounting |
| `scripts/stage-claude-config.sh` | Copies your host skills, agents and `CLAUDE.md` into the kit |
| `scripts/install-playwright-browsers.sh` | Fetches the browsers the *workspace's* Playwright pins, into the shared cache |
| `scripts/init-worktree.sh` | Names the real git dir when the checkout is a linked worktree |
| `scripts/init-git-identity.sh` | Reads your git author identity off the host |
| `scripts/lib/ports.sh` | Moves a published host port off one the host already uses |
| `scripts/lib/profile.sh` | How a workspace gets its profile |
| `turbo-cache/docker-compose.yml` | Standalone [Turborepo remote cache](https://ducktors.github.io/turborepo-remote-cache). **Dormant** — turbo caches to a shared host directory now |
| `../observability/` | Standalone OpenTelemetry Collector, Prometheus and Grafana ([README](../observability/README.md)) |

## Details

**Shared caches are host directories.** All four of them, where the devcontainer
used named Docker volumes:

| Directory | Reached as | Holds |
| --- | --- | --- |
| `~/.cache/devbox/yarn-berry` | `YARN_GLOBAL_FOLDER` | Yarn's package cache and metadata index |
| `~/.cache/devbox/turbo` | `TURBO_CACHE_DIR` | Turborepo's cache |
| `~/.cache/devbox/ms-playwright` | `PLAYWRIGHT_BROWSERS_PATH` | Playwright's browser builds |
| `~/.local/share/devbox/tools/<profile>` | `$DEVBOX_TOOLS` | Whatever the profile's `setup.sh` installs |

- A kit volume is block or tmpfs storage *inside* the VM, and there is no kit
  field or `sbx` flag for a host bind mount — an extra workspace argument to
  `sbx create` is the only way in. Which is fine, because these four have to be
  shared across every workspace anyway, and a volume is per-sandbox.
- Same-path mounting means the variable above is the host path verbatim. No
  canonical-path trick, no subpaths, no chown: the host user is uid 1000 and so
  is the sandbox's `agent`.
- `du -sh` and `rm -rf` work on all of them without a sandbox. Losing any one
  costs a slow install, nothing more.
- Your host shares the turbo cache too: export
  `TURBO_CACHE_DIR=~/.cache/devbox/turbo` for a `turbo run` outside any sandbox.
  Two sandboxes building the same task write the same hash to the same directory;
  the contents are identical, so the loser of that race overwrites the winner —
  the one thing a cache *server* serialised and a directory does not.
- `YARN_ENABLE_GLOBAL_CACHE=true` is the other half of the yarn entry. A repo
  whose `.yarnrc.yml` sets `enableGlobalCache: false` is right on a host and
  wrong here, where the project cache would land on the workspace mount —
  hundreds of megabytes of zips per checkout, shared with no one. Env beats
  `.yarnrc.yml`, so the checked-in config and CI are untouched.

**What is a volume.** Three things, all declared in the generated kit and all
per-sandbox: the GitNexus index over `<workspace>/.gitnexus`, whatever a profile
declares in its `volumes` file, and the built-in `claude` kit's own mounts over
`~/.claude/projects`, `sessions`, `todos`, `shell-snapshots` and `statsig`.

They are named deterministically after the sandbox, so they survive
`devbox rebuild` — and they do **not** survive `devbox down`, which is the one
real regression from `docker compose down`. Use `stop` unless you mean it.

**Git worktrees work in here.** A linked worktree's `.git` is a file pointing at
an absolute host path, which normally means "not a git repository" inside a
container. `scripts/init-worktree.sh` names the real git dir and `devbox` passes
it as an extra workspace — mounted at the same path it has on the host, so the
pointer and the `commondir` link beside it resolve unchanged.

- One mount, where the devcontainer needed four. Same-path mounting removes two
  of them, and the read-only mount over the shared `worktrees/` directory went
  with them.
- That mount was what made unregistering a *sibling* worktree fail at the kernel.
  What is left is `gc.worktreePruneExpire never`, set by the kit at create, which
  covers `git gc --auto` but **not** an explicit `git worktree prune`. Don't run
  that in here.

**Git identity.** Your `user.name` and `user.email` are read on the host and
written into the sandbox's global git config by the kit's `setup.install`, so
commits made in here are authored by you instead of failing with "Please tell me
who you are".

- Read from the workspace root, not `--global`, so the **effective** identity
  wins — a repo-local address on a work checkout is what the host would commit
  with, and what should apply in here. Check with `git config --get user.email`
  in the checkout.
- Deliberately not `GIT_AUTHOR_*`/`GIT_COMMITTER_*`: those override even a
  repo-local identity set inside the sandbox, and leave `git config user.email`
  answering nothing.
- Applied at **create**, so changing your host identity needs a rebuild — or just
  run `git config --global user.email ...` in the sandbox.

**Host config staging.** The sandbox's `~/.claude` shares nothing with the host,
so `scripts/stage-claude-config.sh` copies the three parts worth sharing —
`$CLAUDE_CONFIG_DIR/skills`, `$CLAUDE_CONFIG_DIR/agents` and
`$CLAUDE_CONFIG_DIR/CLAUDE.md`, falling back to `~/.claude` — into the kit's
`files/home/.claude/`, which sbx unpacks into `/home/agent` at create.

- Symlinks are dereferenced on the host — the reason for the staging step. A
  skill pointing at another checkout isn't mounted into the sandbox and the link
  would dangle.
- The kit is rebuilt from scratch on every create, so removing a skill on the
  host removes it here. That replaces the manifest-driven prune the container
  needed. It also means a skill written *inside* a sandbox is not protected —
  it survives a restart, not a `rebuild`.
- **To turn it off**, `touch ~/.local/state/devbox/<sandbox>/skip-host-config`,
  or set `DEVBOX_SKIP_HOST_CONFIG=1` for the `devbox` invocation.
- Project-level skills (`.claude/skills/`) and memory (`./CLAUDE.md`) need none
  of this — the workspace mount already carries them.

**GitNexus.** [GitNexus](https://github.com/abhigyanpatwari/GitNexus) indexes a
checkout into a code knowledge graph and serves it to Claude Code over MCP. It is
installed globally in the `Dockerfile`, not by a profile, because it reads any
repository and pins nothing — the same reason Volta is there.

```bash
devbox shell
gitnexus analyze --index-only   # build the index
gitnexus mcp                    # serve it (stdio)
```

- **Use `--index-only`.** A bare `gitnexus analyze` also injects `AGENTS.md`,
  `CLAUDE.md` and `.claude/skills/gitnexus/` into the repository root — three
  untracked entries in `git status`, in *your* checkout, through the workspace
  mount.
- **The index is a volume**, mounted over `<workspace>/.gitnexus` by the kit, so
  the database, its WAL and the parse caches never reach the host checkout — and
  never sit on virtiofs, which is the wrong filesystem for that workload. Per
  sandbox: an index describes one checkout, and rebuilding costs one `analyze`.
- **Full-text search needs an extension**, `fts` for LadybugDB, which `analyze`
  otherwise downloads from `extension.ladybugdb.com` on first run — a host the
  allowlist blocks. Without it `analyze` still succeeds and only *warns*, leaving
  an index whose BM25 search is dead. The `Dockerfile` fetches it at build time,
  as `agent`, so nothing needs the allowlist.
- `analyze` and `mcp` are otherwise **fully offline**. Only `--embeddings` and
  `gitnexus wiki` reach the network, and both are opt-in.

**Reaching the host.** A sandbox cannot join a host Docker network and cannot
resolve a host container by name. What it can reach is a port published on the
host, through `host.docker.internal`, which the base allowlist grants. Two things
depend on it:

- **Claude Code's telemetry** pushes OTLP to `host.docker.internal:4317` — the
  collector in `../observability/`, which publishes that port on the host. Every
  sandbox reports, whatever its profile, and the `workspace` and `devbox.profile`
  resource attributes are what a panel breaks spend down by.
- **The shared MongoDB** (`rocketchat` profile) is reached the same way. It costs
  `directConnection=true` — the replica set advertises its member as
  `mongo:27017`, a name that does not resolve in here — and with it the oplog
  tail; see the note in `projects/rocketchat/env`.

**What Prometheus lost.** The `devbox` scrape job in `../observability/`
discovers containers through the host Docker daemon, and a sandbox's containers
live in the VM's own daemon. Nothing is scraped from a sandbox any more. Claude
Code's telemetry is unaffected, because it pushes.

## Documentation

- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) — the backend, and its [kit specification](https://docs.docker.com/ai/sandboxes/customize/kits/)
- [Permission modes](https://code.claude.com/docs/en/permission-modes) and the [CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Security model](https://code.claude.com/docs/en/security) and [sandbox environments](https://code.claude.com/docs/en/sandbox-environments)
- [The `.claude` directory](https://code.claude.com/docs/en/claude-directory) — what the persisted volumes actually hold
