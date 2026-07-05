# Claude Code sandbox devcontainer

A dev container that lets Claude Code (and other agents) work **without permission
prompts**, safely, because the container is isolated:

- **Filesystem** — only your project is mounted (`/workspace`); the rest of your
  host is invisible.
- **Network** — `init-firewall.sh` drops all outbound traffic except an
  allowlist (DNS, SSH, host LAN, GitHub's ranges, npm, and the Anthropic API).

Because of that isolation, the `claude` command inside the container is aliased to
`claude --dangerously-skip-permissions`. Use `claude-ask` if you want the normal
prompts back for a session.

## Add it to a project

From the dotfiles repo, `scripts/` is on your `PATH`, so from any project root:

```sh
add-devcontainer.sh          # copies this template into ./.devcontainer
add-devcontainer.sh --force  # overwrite an existing one
```

### Git worktrees: use `--worktree`

A linked worktree's `.git` is a *file* pointing at an absolute host path under the
main checkout's `.git`. A plain single-folder mount doesn't include that path, so
git breaks inside the container. Run this **from inside the worktree** instead:

```sh
add-devcontainer.sh --worktree
```

It writes `.devcontainer/` at the worktree root with a config that bind-mounts
**both the worktree and the main checkout at their identical host paths**, so the
absolute pointers resolve and git just works. It also shares one Claude auth
volume (`claude-code-config-shared`) across all worktrees, so you log in once.

Each worktree still gets its own container (keyed by folder), which is what you
want for running agents in parallel. Note the mounts use real host paths, so
`workspaceFolder` is the worktree's actual path, not `/workspace`.

Then either:

- **VS Code** — "Dev Containers: Reopen in Container", or
- **CLI** — `devcontainer up --workspace-folder .` then `devcontainer exec --workspace-folder . zsh`
  (needs `npm i -g @devcontainers/cli`).

## First run

1. The container builds, then `postCreateCommand` runs the firewall (you'll see
   "Firewall verification passed" twice).
2. Inside, run `claude` and log in **once** — auth is stored on a named volume
   (`/home/node/.claude`) and survives rebuilds.
3. For GitHub access, either `gh auth login` inside the container, or export
   `GITHUB_TOKEN` on the host before opening (it's forwarded via `remoteEnv`).

## Tuning

- **Allow more hosts**: add domains to `ALLOWED_DOMAINS` in `init-firewall.sh`.
  After editing, re-run `sudo /usr/local/bin/init-firewall.sh` in the container.
- **Timezone**: set `TZ` on the host or edit the default in `devcontainer.json`.

## Files

| File | Purpose |
| ---- | ------- |
| `devcontainer.json` | Container definition, mounts, `NET_ADMIN` caps, env forwarding |
| `Dockerfile` | node:22 base + zsh + Claude Code + the `claude` bypass alias |
| `init-firewall.sh` | Outbound allowlist; runs on create and is re-runnable |
