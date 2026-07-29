# Dev container troubleshooting

Companion to `./troubleshoot.sh`. Run the script from the **host**, at the repo root.

```
./.devcontainer/troubleshoot.sh            # drift + mounts + firewall + hang
./.devcontainer/troubleshoot.sh drift      # is the container running your edits?
./.devcontainer/troubleshoot.sh mounts     # volumes, ownership, host-path leaks
./.devcontainer/troubleshoot.sh firewall   # egress policy, and is it blocking anything?
./.devcontainer/troubleshoot.sh hang [pid] # progressing, blocked, or spinning?
./.devcontainer/troubleshoot.sh profile [pid]   # name the function it is looping in
```

Overrides: `RC_CONTAINER` (skip auto-detect), `RC_SAMPLE` (hang window, default 30s),
`RC_PROFILE` (profile duration, default 15s).

---

## Rule 0 — rule out staleness before believing anything

**`devcontainer up` attaches to an existing container and skips the build entirely.**
Re-running it after editing the `Dockerfile` is a no-op. Rebuilding with
`docker compose build` doesn't help either: the CLI runs a *derived* image
(`vsc-<folder>-<hash>`) with the feature layers applied on top, so a plain compose
build produces something that is never used.

To actually pick up config changes:

```
npx @devcontainers/cli up --workspace-folder . --remove-existing-container
```

Named volumes survive this; only the container's writable layer is discarded.

`troubleshoot.sh drift` checks three independent signals — config files newer than
the container, the firewall script's md5 against the working tree, and every
Dockerfile `ENV` against the image. Fix drift before investigating anything else.

> Two separate debugging sessions were lost to this. Symptoms that "don't respond
> to the fix" are stale containers until proven otherwise.

Beware of timestamps when checking by hand: `docker inspect -f '{{.Created}}'`
prints **UTC**, `docker ps --format '{{.CreatedAt}}'` prints **local time**. Comparing
the two directly makes a fresh container look hours old.

---

## Known traps

| Symptom | Cause | Fix |
|---|---|---|
| Edits to `Dockerfile` have no effect | `up` attached to an existing container | `--remove-existing-container` |
| Firewall script isn't the one in the repo | The `claude-code` feature installs **its own** `/usr/local/bin/init-firewall.sh`, and features are layered *after* the Dockerfile | Ship ours as `rc-init-firewall.sh`; never use the unprefixed name |
| `EACCES` under `node_modules` or `.meteor/local` | An empty named volume mounts `root:root`; the image has nothing at that path to seed ownership from | `chown` the mount point in `postCreateCommand` (non-recursive is enough) |
| Meteor re-downloads its whole distribution | The launcher resolves `METEOR_WAREHOUSE_DIR:-$HOME/.meteor`; installing to `/usr/local/meteor` without setting the var leaves it invisible | `ENV METEOR_WAREHOUSE_DIR=/usr/local/meteor` |
| Meteor downloads meteor-tool on first project run | `install.meteor.com` installs the *newest* release; the project pins its own in `apps/meteor/.meteor/release` | `curl "https://install.meteor.com/?release=$(sed 's/^METEOR@//' …)"` |
| Broken symlinks, or Meteor behaving differently to the host | `.meteor/local` was shared through the workspace bind mount; Meteor writes **absolute** paths into it (`dev_bundle -> /home/<hostuser>/…`) | Give it its own named volume |
| A host looks blocked but nothing appears in `SYN-SENT` | The firewall REJECTs, so blocked connections fail in ~1 ms and never queue | Watch the **REJECT packet counter**, not socket state |
| Firewall verification reports a working host as unreachable | `curl -sI` (HEAD) is slow on cold connections; `-f` treats 404/403 as failure | Use a GET and accept any `http_code != 000` |
| `<defunct>` processes accumulate | PID 1 is `sleep infinity`, which never reaps orphans | Harmless; add `init: true` to the compose service if it bothers you |
| Mongo won't start | MongoDB 8.0 refuses to run on Linux kernel ≥ 6.19 (SERVER-121912) | Not hit here — Meteor's bundled mongod is 7.0.16 |
| `yarn dsv` starts no mongod, then fails to connect | `MONGO_URL`/`MONGO_OPLOG_URL` were set (leftover from a `mongo` compose service, or a hand-edited `/etc/environment`). Meteor only launches its bundled mongod when `MONGO_URL` is **unset**, and the `mongo` hostname doesn't resolve without that service | Unset both and rebuild the container — container env is fixed at create time, so editing the compose file is not enough |

---

## Reading `hang`

The script samples over a window and compares deltas:

| Signal | Meaning |
|---|---|
| REJECT counter rising | The firewall is blocking this workload — add the host to `ALLOWED_DOMAINS` |
| CPU ≈ 0%, state `S`/`D` | Blocked on I/O, a lock, or the network — check `.meteor/local/lock` |
| CPU high **+** children or build output | Progressing, just slow |
| CPU high, no children, no output, RSS flat/falling | **Spinning** — a real build grows memory and emits files |

The last row is the interesting one. Note that activity in
`/usr/local/meteor/package-metadata` is deliberately **not** counted as progress:
Meteor churns SQLite journal files there continuously while spinning, and counting
it produces a false "healthy" verdict.

`profile` sends `SIGUSR1` so Node opens its inspector on `127.0.0.1:9229` (loopback,
which the firewall permits), records a CPU profile over CDP, and prints the hottest
frames by self time. It attaches a debugger to a live process — it does not kill it,
but ask before running it against someone else's session.

---

## Fixes already applied

| File | Change |
|---|---|
| `Dockerfile` | Firewall script installed as `rc-init-firewall.sh`, dodging the feature's overwrite |
| `Dockerfile` | `METEOR_WAREHOUSE_DIR` set; dead `METEOR_INSTALL` / `$METEOR_INSTALL/bin` PATH entry removed; warehouse chowned in the *same layer* as the install (a separate `RUN` would duplicate ~1 GB) |
| `Dockerfile` | Meteor release read from `apps/meteor/.meteor/release` so the image ships the tool the project actually pins |
| `init-firewall.sh` | `static.meteor.com` added to the allowlist |
| `docker-compose.yml` | `.meteor/local` moved onto the `rc-meteor-local` volume |
| `devcontainer.json` | `postStartCommand` retargeted; `postCreateCommand` chowns both volume mount points |

---

## Open problem — Meteor spins in the package catalog

**Status: unresolved.** `yarn dsv` runs meteor-tool at ~140–150% CPU indefinitely.

Confirmed by measurement:

- No network activity at all (REJECT counter static, no established connections) —
  **not** a firewall problem
- No child process ever spawned, so it never reaches `npm run dev`
- No build output; `.meteor/local` stays empty
- RSS *falls* over time (125 → 100 → 80 MB) rather than growing
- The only filesystem activity is `/usr/local/meteor/package-metadata/v2.0.1`, whose
  directory mtime advances while `packages.data.db` itself never changes — i.e.
  SQLite journal files being created and deleted in a loop
- The catalog itself is healthy: valid SQLite header, 452 MB fully allocated (not
  truncated), writable by `vscode`, 300+ GB free

A false lead worth recording: the dangling `.meteor/local/dev_bundle ->
/home/<hostuser>/…` symlink was a real bug and is fixed, but it was **not** the cause.
The spin reproduces with `.meteor/local` empty on its own volume. Meteor never gets
far enough to create `dev_bundle` at all.

### Next steps, in order

1. **Profile it.** `./.devcontainer/troubleshoot.sh profile <pid>` names the function
   consuming the CPU. Everything below is guesswork until this is done.
2. **Rebuild first.** The `?release=` pin is not in the current image (the warehouse
   holds both 3.5.0 and 3.4.1, so 3.4.1 arrived at runtime). Rebuild and confirm
   `meteor --version` reports **3.4.1**, then re-test — this changes which tool *and*
   which catalog ship in the image.
3. **Bisect against a clean warehouse.** Point `METEOR_WAREHOUSE_DIR` at an empty
   directory and let Meteor bootstrap from scratch (`static.meteor.com` is
   allowlisted). If that works, the catalog baked into the image is at fault.
4. **Compare with the host.** The same project builds on the host, so diff the two
   warehouses — particularly the size and date of
   `package-metadata/v2.0.1/packages.data.db`.
5. **Force a catalog refresh.** If 3 or 4 implicate the catalog, remove
   `packages.data.db` and let Meteor re-sync from `packages.meteor.com`.
