# devbox — a dev container for whatever you're working on

A network-isolated container that wraps any checkout on this machine. The
definition lives here, in the dotfiles; the source code comes from your pwd:

```bash
cd ~/dev/RocketChat/worktrees/main
devbox up          # build/start a container with this checkout mounted
devbox claude      # Claude Code, --dangerously-skip-permissions, behind a firewall
devbox shell       # zsh in there
```

Nothing is added to the repository you are working on — no `.devcontainer/`, no
committed compose file. One image, one set of shared caches and logins, one
firewall, for every checkout.

Prerequisites: Docker and the [`devcontainer`
CLI](https://github.com/devcontainers/cli) (`volta install @devcontainers/cli`).
`devbox` is `dotfiles/scripts/devbox`, which is on `$PATH` through
`$DOTFILES_SCRIPTS`.

## The command

| | |
| --- | --- |
| `devbox up` | Create/start the container for this workspace |
| `devbox shell [cmd]` | A shell inside it (zsh) |
| `devbox exec CMD...` | Run one command inside it |
| `devbox claude [args]` | Claude Code with `--dangerously-skip-permissions` |
| `devbox stop` / `down` | Stop it / stop and remove it |
| `devbox rebuild [--no-cache]` | Recreate it, re-running create-time setup |
| `devbox status` / `env` | What's running / everything resolved for this pwd |

`--profile <name>` forces a profile, `--workspace <path>` works on a directory
other than the pwd. `shell`, `exec` and `claude` start the container if it isn't
running.

## How one config serves every checkout

`devbox` points the devcontainer CLI at `devcontainer.json` in here with
`--workspace-folder` set to your pwd, and derives the rest of the wiring from
that path:

| | |
| --- | --- |
| `DEVBOX_WORKSPACE_SLUG` | The path minus `$HOME`, so the container's workspace is `/workspaces/dev/RocketChat/worktrees/main` — distinct per checkout, with the checkout's own name still the leaf |
| `COMPOSE_PROJECT_NAME` | `devbox-<dirname>-<hash of the full path>`, read by the devcontainer CLI, so two checkouts never share a container |
| `DEVBOX_PROFILE` | The `projects/<name>` profile whose `match` claims this path |
| `DEVBOX_STATE` | `~/.local/state/devbox/<project>/` — the generated compose override and the staged Claude Code skills |

Nothing is stored: run any subcommand from the same directory and it resolves to
the same container. The flip side is that **the CLI has to be driven through
`devbox`** — `devcontainer up` on its own leaves those variables empty, and
`scripts/initialize.sh` stops with an error saying so.

This directory is also bind-mounted **read-only** at `/opt/devbox` in the
container, which is how the lifecycle scripts, the firewall and the profiles get
in there without living in your repo. Editing any of them takes effect on a
**restart**; only the `Dockerfile` needs a rebuild.

## Network isolation

The `claude-code` feature brings a **default-deny egress firewall**, re-applied
on every start because iptables state does not persist. IPv4 allowlist only,
IPv6 blocked outright. That is what makes `--dangerously-skip-permissions` a
bounded risk here: no permission prompt reviews a tool call, but the call runs
in a container, as the non-root `vscode` user (the CLI *refuses* the flag as
root), and can only reach the allowlist.

Watch the `postStartCommand` output for `verified: https://example.com is
blocked as expected` — no line, no firewall.

The allowlist is data, assembled at every start from four places:

| | |
| --- | --- |
| `allowed-domains` | The floor: GitHub, the npm/yarn registries, the editor, the turbo cache's CIDR |
| `scripts/<feature>/allowed-domains` | Merged only while that feature is declared (Claude's own hosts, Playwright's CDN) |
| `projects/<profile>/allowed-domains` | Merged for workspaces on that profile |
| `DEVBOX_ALLOW_DOMAINS="a.example b.example"` | One-off, at `devbox up` time |

Hostnames are resolved at start; IPs and CIDRs go in as-is; a name that fails to
resolve is skipped with a warning rather than taking the firewall down with it.
Adding one needs a container **restart**, no rebuild. Confirm what landed with
`sudo ipset list allowed-domains`.

What the firewall does **not** bound is the workspace: it is a bind mount, so
anything Claude writes lands in your host checkout, and your GitHub token and SSH
key are reachable from inside. Use it on repositories you trust. See Anthropic's
[permission modes](https://code.claude.com/docs/en/permission-modes) if you want
fewer prompts without disabling the checks.

## Profiles

The image is deliberately generic — a Node/Yarn/pnpm toolchain through Volta and
nothing that belongs to any one repository. A **profile** is how a repo's own
setup reaches it: its dependency install, the extra hosts it needs, its ports,
its environment. One is picked per workspace by matching your path against each
`projects/<name>/match`.

```
projects/rocketchat/
  match              ~/dev/RocketChat/worktrees/*
  env                METEOR_WAREHOUSE_DIR=..., DENO_INSTALL=..., MONGO_URL=...
  env.local          gitignored — a license key
  ports              3000:3000
  allowed-domains    *.meteor.com, *.rocket.chat, the mongo network's CIDR
  setup.sh           pinned Meteor + Deno into $DEVBOX_TOOLS, then yarn install/build
  initialize.sh      host-side; brings up the shared MongoDB before create
  compose/*.yml      node_modules and .meteor/local as volumes, off the bind mount;
                     the mongo stack's network, attached as external
```

Every file is optional; `default` is the fallback and is empty on purpose. Each
profile also gets `$DEVBOX_TOOLS` (`~/.devbox`) — a volume shared by every
workspace on that profile, and the only writable place that survives a rebuild,
which is where a `setup.sh` puts toolchains it downloads. See
[`projects/README.md`](projects/README.md) for the full contract.

## Features

Optional DX is opt-in through the `features` block in `devcontainer.json`.
Comment one out and everything it brings — lifecycle steps, volumes, mounts,
capabilities, allowlist entries — disappears with it; no other file needs
editing.

| Feature | Gives you |
| --- | --- |
| `anthropics/devcontainer-features/claude-code` | The Claude Code CLI, the egress firewall, your host skills, a shared login |
| `devcontainers/features/github-cli` | `gh`, plus a shared login and SSH key |
| `postfinance/devcontainer-features/playwright-deps` | Headless-Chromium OS libraries, plus the browser build fetched by the *workspace's* Playwright and a shared cache volume |
| `devcontainers-extra/features/npm-packages` | Global CLIs for every workspace (empty by default — project-specific ones belong in a profile) |

A directory under `scripts/` that ships a `feature.id` file belongs to the
feature named in it, and **nothing inside it runs unless `devcontainer.json`
declares that feature**. Hook names match the top-level ones (`initialize.sh`,
`on-create.sh`, `update-content.sh`, `post-start.sh`) and are called from them.
Directory names aren't derived from feature ids — `gh` owns
`devcontainers/features/github-cli` — the file is the mapping.

To add a feature with setup of its own: create `scripts/<name>/`, put the feature
id in `scripts/<name>/feature.id`, add whichever hooks you need, contribute
compose bits with `overrides_add <name> <bucket>` and hosts with
`scripts/<name>/allowed-domains`. Then declare the feature. Nothing else wires it
up.

### Logging in

Once, in any workspace — the volumes are shared by all of them:

```bash
devbox exec claude       # follow the browser auth prompt
devbox exec gh auth login  # pick SSH and let it generate a key
```

Do it **inside** the container, not on the host. If the browser callback never
reaches the container, paste the code shown in the browser at the
`Paste code here if prompted` prompt.

## Structure

| File | Purpose |
| --- | --- |
| `devcontainer.json` | User, features, env, lifecycle hooks, the workspace path and the mounts that track it |
| `docker-compose.yml` | The service, and the volumes neither a feature nor a profile owns |
| `Dockerfile` | Base image and the generic toolchain |
| `allowed-domains` | The base egress allowlist |
| `projects/` | Per-repository profiles ([contract](projects/README.md)) |
| `turbo-cache/docker-compose.yml` | Standalone [Turborepo remote cache](https://ducktors.github.io/turborepo-remote-cache), its own project so one cache serves every workspace |
| `scripts/initialize.sh` | Host-side `initializeCommand`; runs the ensure-scripts, then merges the compose fragments |
| `scripts/on-create.sh` | Container-side `onCreateCommand`; claims volume mount points, configures git |
| `scripts/update-content.sh` | Container-side `updateContentCommand`; the profile's `setup.sh`, then the features' install steps |
| `scripts/post-start.sh` | Container-side `postStartCommand`; the firewall, via the claude-code feature |
| `scripts/init-profile.sh` | Host-side; the profile's env, ports, tools volume, compose fragments and its own `initialize.sh` |
| `scripts/init-worktree.sh` | Host-side; exposes the real git dir when the checkout is a linked worktree |
| `scripts/init-git-identity.sh` | Host-side; passes your git author identity through |
| `scripts/ensure-*.sh` | Host-side; the shared volumes and the turbo cache, before create |
| `scripts/lib/features.sh` | Which `scripts/<feature>/` directories are active, read off `devcontainer.json` |
| `scripts/lib/overrides.sh` | How the generated compose override gets built |
| `scripts/lib/ports.sh` | Moves a published host port off one the host already uses |
| `scripts/lib/profile.sh` | How a workspace gets its profile |

The `ensure-*` scripts are host-side and pre-create rather than lazy for one
recurring reason: compose refuses to create the container when an `external`
volume or network is missing, and a `subpath` mount fails if that path isn't
already inside the volume.

**Why a compose file is generated.** Compose is static and
`devcontainer.json`'s `dockerComposeFile` list can't be computed, yet nearly
everything specific to a container is only knowable on the host at
`initializeCommand` time: the workspace's profile, whether the checkout is a
linked worktree, which features are declared. A feature's volume is `external`,
and compose refuses to create the container at all when an external volume
doesn't exist — so checking those mounts in would mean commenting a feature out
*breaks* the container instead of shrinking it. Each contributor stages a
fragment and `scripts/initialize.sh` merges them in one pass, into
`$DEVBOX_STATE` — per workspace, since several can be up at once.

## Details

**Shared volumes.** Each is mounted at exactly the path its tool reads by
default, so a login or a download lands in the volume with nothing to configure
and nothing to copy — including after a rebuild. Subpaths let one volume carry
several mounts, and need Compose ≥ 2.26 / Engine ≥ 25.

| Volume | Subpath | Mounted at | Holds |
| --- | --- | --- | --- |
| `devbox-yarn-cache` | `berry/` | `~/.yarn/berry` | Yarn's package cache and metadata index |
| `devbox-playwright-browsers` | `ms-playwright/` | `~/.cache/ms-playwright` | Playwright's browser builds, one directory per version |
| `devbox-claude-config` | — | `~/.claude` | Claude Code credentials, settings, history, skills |
| `devbox-gh-auth` | `gh/` | `~/.config/gh` | `hosts.yml`, i.e. the GitHub OAuth token |
| `devbox-gh-auth` | `ssh/` | `~/.ssh` | The SSH key `gh auth login` generates, plus `known_hosts` |
| `devbox-tools-<profile>` | — | `~/.devbox` | Whatever the profile's `setup.sh` installs |

- Being `external` with a **fixed** name is what makes them shared across every
  workspace, and also keeps them out of reach of `compose down -v`. For the same
  reason none can be a `mounts` entry in `devcontainer.json`: those become
  ordinary volumes in a generated override and get the project prefix too.
- Canonical paths are the point, and for `gh` there's no alternative — its key
  generation is hardcoded to `$HOME/.ssh` with no flag to move it.
- The auth volumes are created `0700` and owned by the host uid (which is the
  container user's, since devcontainers matches them). The rest are cache:
  `docker volume rm devbox-yarn-cache` costs one slow install, nothing more.
- `~/.claude` is shared *state* — login, settings, skills and history for every
  workspace on the machine. Per-project state still stays apart: the workspace
  path carries the checkout's full host path, so each resolves to its own entry
  under `~/.claude/projects/` and `claude --resume` only lists that checkout's
  sessions.
- To log out everywhere: `claude /logout` and `gh auth logout`, or
  `docker volume rm devbox-claude-config devbox-gh-auth` with no container running.

**The workspace path.** `/workspaces/${DEVBOX_WORKSPACE_SLUG}` — the host path
minus `$HOME`, e.g. `/workspaces/dev/RocketChat/worktrees/main`.

- The point is tools that key state by absolute path. Chief among them Claude
  Code, whose `~/.claude/projects/<flattened-path>` would otherwise be one shared
  entry for every checkout, since they all mount the one config volume.
- The leaf is still the checkout's own directory name, so the prefix shows up in
  neither the VS Code window title nor the shell prompt. `pwd` is where you'll
  see it.
- **Not `${devcontainerId}`**, which is what you'd reach for first and is broken
  for this: `devcontainer up` substitutes it, but `devcontainer exec` resolves the
  config with *no* id labels, so the literal `${devcontainerId}` survives into the
  exec cwd and every command fails with `chdir to cwd (…) no such file or
  directory`. Nothing on the command line fixes it, `--id-label` included.
- The workspace bind mount therefore lives in `devcontainer.json`'s `mounts`
  rather than `docker-compose.yml`: its target has to track this path, and no
  compose file can resolve these variables. A profile that needs a volume *inside*
  the workspace uses the `%WORKSPACE%` placeholder in a compose fragment.
- Never hardcode the path in a container-side script. Use `$DEVBOX_WORKSPACE`,
  which `containerEnv` sets from `${containerWorkspaceFolder}`.

**Git worktrees work in here, and can't be damaged from in here.** A linked
worktree's `.git` is a file pointing at an absolute host path, which normally
means "not a git repository" inside a container. Instead of rewriting anything:

- The real git dir is bind-mounted at the *same absolute path* it has on the
  host, so the pointer resolves unchanged.
- The shared `worktrees/` admin directory is mounted **read-only**, with a
  writable hole for this worktree's own admin dir. Every *other* worktree looks
  prunable from in here (their host paths aren't mounted), and read-only makes
  unregistering one fail at the kernel — no git command can do it, however it's
  invoked.
- `gc.worktreePruneExpire never` is set as a second belt for `git gc --auto`.
  (It does not cover an explicit `git worktree prune`, which ignores the config.
  Don't run that in here.)

**Git identity.** Your `user.name` and `user.email` are read on the host at
`initializeCommand` and written into the container's global git config at create,
so commits made in here are authored by you instead of failing with "Please tell
me who you are".

- Read from the workspace root, not `--global`, so the **effective** identity
  wins — a repo-local address on a work checkout is what the host would commit
  with, and what should apply in here. Check what will be picked up with
  `git config --get user.email` in the checkout.
- Travels as `DEVBOX_GIT_USER_NAME`/`DEVBOX_GIT_USER_EMAIL` on the service, which
  `scripts/on-create.sh` converts into real config. Deliberately not
  `GIT_AUTHOR_*`/`GIT_COMMITTER_*`: those override even a repo-local identity set
  inside the container, and leave `git config user.email` answering nothing.
- Applied at **create**, so changing your host identity needs a rebuild to take
  effect — or just run `git config --global user.email ...` in the container.

**Turborepo remote cache.** Reached at `http://turbo-cache:3000` over the shared
external `turbo-cache` network (`TURBO_API`/`TURBO_TEAM`/`TURBO_TOKEN` in
`devcontainer.json`), and at `http://127.0.0.1:3399` from the host for builds
outside the container. It starts via `initializeCommand`; if Docker is
unavailable the script warns and builds simply run uncached.

- The network is pinned to `172.30.0.0/24` because the base allowlist has that
  CIDR — the automatic host-network rule only covers the container's own bridge.
  Change one, change both.
- `TURBO_TOKEN` is a fixed local-dev value, not a secret. Change it in both
  places or every request 401s. To wipe artifacts:
  `docker compose -f turbo-cache/docker-compose.yml down -v`.
- `TURBO_CACHE_DIR=.turbo/cache` is **required in a worktree**. turbo ≥ 2.9 is
  worktree-aware and otherwise writes the local cache into the *main* worktree —
  a host path that exists in here only as a root-owned mount parent, so builds
  fail with `Permission denied`.
- **No `turbo login`/`turbo link` is needed, or possible.** Those three env vars
  *are* the hookup. Both commands are TTY-only and fail with `IO error: not a
  terminal` from any lifecycle hook. To confirm the cache is live, run a
  cacheable task twice with `.turbo/cache` removed in between.

**The shared MongoDB (`rocketchat` profile).** `../local-mongo/docker-compose.yml`
is a stack of its own — one database for every worktree, up and down
independently of any container in here — and the profile reaches it at
`mongo:27017` over its network, which is named `local-mongo` and attached as
`external`. `projects/rocketchat/initialize.sh` starts it at
`initializeCommand`, because compose won't create a container whose external
network is missing.

- **Only the `mongo` service.** That file also defines nats and traefik, and
  traefik publishes host port 3000 — the port this profile publishes for Meteor.
  Bringing the whole file up from here would fail every `devbox up` on an
  allocated port. Start the rest by hand when you want the microservices stack.
- The hostname is not cosmetic: the replica set advertises its member as
  `mongo:27017`, and a driver connecting to a replica set uses the *advertised*
  address, not the one you gave it. A published port alone doesn't work.
- Pinned to `172.31.0.0/24` because `projects/rocketchat/allowed-domains` has
  that CIDR — a second network isn't covered by the rule the firewall derives
  from its own bridge. Change one, change both.
- `MONGO_URL` in `projects/rocketchat/env` is what makes Meteor skip its bundled
  mongod, so nothing listens on 3001 any more and `ports` no longer publishes
  it. Comment both back in to go back to the bundled database.
- Still reachable from the host at `127.0.0.1:27017` (mongosh, Compass) while
  the container uses it.

**Yarn's global cache.** `YARN_ENABLE_GLOBAL_CACHE=true` (`devcontainer.json`) is
the other half of the volume above. A repo whose `.yarnrc.yml` sets
`enableGlobalCache: false` — the cache belongs to the project — is right on a host
and wrong in here, where the project cache would live in the bind mount: hundreds
of megabytes of zips per checkout, shared with no one. Env beats `.yarnrc.yml`,
so the checked-in config and CI are untouched. Verify with
`yarn config get cacheFolder` — it should be under `/home/vscode/.yarn/berry`,
not `/workspaces`.

**GitNexus.** [GitNexus](https://github.com/abhigyanpatwari/GitNexus) indexes a
checkout into a code knowledge graph and serves it to Claude Code over MCP. It is
installed globally in the `Dockerfile`, not by a profile, because it reads any
repository and pins nothing — the same reason Volta is there. Run it from a
workspace:

```bash
devbox shell
gitnexus analyze --index-only   # build the index
gitnexus mcp                    # serve it (stdio)
```

- **Use `--index-only`.** A bare `gitnexus analyze` also injects `AGENTS.md`,
  `CLAUDE.md` and `.claude/skills/gitnexus/` into the repository root — three
  untracked entries in `git status`, in *your* checkout, through the bind mount.
  `--index-only` skips all file injection. `--skip-agents-md` and `--skip-skills`
  suppress them individually.
- **The index does not dirty the checkout.** `.gitnexus/` cannot be relocated —
  the path is hardcoded — but the tool writes `.gitnexus/.gitignore` containing
  `*`, which hides the directory from `git status` on its own. It also appends
  `.gitnexus/` to `.git/info/exclude`, though only when `.git` is a directory, so
  that half is skipped in a linked worktree. The self-ignore covers both cases.
- **The index is a volume anyway**, mounted over `<workspace>/.gitnexus` by
  `scripts/initialize.sh`, so the database, its WAL and the parse caches never
  reach the host checkout. Per workspace, not shared: an index describes one
  checkout. Rebuilding it costs one `analyze`, so it is fine to lose.
- The checkout still gets an **empty** `.gitnexus` directory on the host, because
  Docker creates a missing mount target before the container runs. The volume
  shadows it, so it stays empty and root-owned; git does not report empty
  directories, so nothing shows up in `git status`. Removing it by hand needs
  `sudo`.
- **Full-text search needs an extension**, `fts` for LadybugDB, which `analyze`
  otherwise downloads from `extension.ladybugdb.com` on first run — a host the
  firewall blocks. Without it `analyze` still succeeds and only *warns*, leaving
  an index whose BM25 search is dead. The `Dockerfile` fetches it at build time,
  as `vscode` (the cache is `$HOME/.lbdb`), so nothing needs the allowlist.
- `analyze` and `mcp` are otherwise **fully offline**. Only `--embeddings`
  (semantic search) and `gitnexus wiki` (LLM-generated docs) reach the network,
  and both are opt-in; add their hosts to `allowed-domains` if you want them.
- The global registry of indexed repos lives at `~/.gitnexus`, which is *not* a
  volume, so a rebuild loses it. It holds paths and metadata only — no index
  data. Set `GITNEXUS_HOME` if you want it somewhere durable.

**Skills staging.** The container's `~/.claude` is a volume that shares nothing
with the host, so `stage-skills.sh` copies `$CLAUDE_CONFIG_DIR/skills` (falling
back to `~/.claude/skills`) into `$DEVBOX_STATE/host-skills`, which is bind-mounted
read-only at `/opt/devbox-skills`, and `install-skills.sh` installs from there on
every start.

- Symlinks are dereferenced on the host — the reason for the staging step. A
  skill pointing at another checkout isn't mounted into the container and the
  link would dangle.
- Copies, not mounts: nothing in the container can write back to your host
  skills, and changes made inside are overwritten on the next start.
- Editing, adding or deleting a skill on the host only needs a **restart**.
  Pruning is driven by `~/.claude/.host-skills.manifest`, so a skill you wrote
  *inside* the container is left alone.
- **To turn it off**, `touch ~/.local/state/devbox/<project>/skip-skills`, or set
  `DEVBOX_SKIP_SKILLS=1` for the `devbox` invocation.
- Project-level skills (`.claude/skills/`) need none of this — the workspace bind
  mount already carries them.

## Anthropic's documentation

- [Development containers](https://code.claude.com/docs/en/devcontainer) — the reference implementation the firewall is adapted from
- [Permission modes](https://code.claude.com/docs/en/permission-modes) and the [CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Security model](https://code.claude.com/docs/en/security) and [sandbox environments](https://code.claude.com/docs/en/sandbox-environments)
- [The `.claude` directory](https://code.claude.com/docs/en/claude-directory) — what the persisted volume actually holds
