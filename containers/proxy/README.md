# Local reverse proxy

One Caddy for the machine. It turns a local service's port number into a name.

```
containers/proxy/up.sh          # start it
http://grafana.localhost        # -> observability-grafana:3000
http://prometheus.localhost     # -> observability-prometheus:9090
http://loki.localhost           # -> observability-loki:3100
http://tempo.localhost          # -> observability-tempo:3200
```

The numbered addresses keep working. `http://127.0.0.1:3030` is the same Grafana
by another door, and every route here is an addition, never a replacement.

## Why the names resolve

Nothing was added to `/etc/hosts`, and nothing has to be. systemd-resolved
answers **any** name under `.localhost` with `127.0.0.1` and `::1`, so a new
route needs one block in `caddy/Caddyfile` and a reload — no second file, no
`sudo`, no step that a fresh machine can forget.

That is also why the TLD is `.localhost` and not `.local`. `.local` belongs to
mDNS, Avahi runs on this machine, and every name would need its own line in
`/etc/hosts` to beat it.

Check a name with `getent ahosts <name>.localhost`. If it ever stops answering —
a machine without systemd-resolved, or a `resolv.conf` out of stub mode — the
fallback is one `/etc/hosts` line per name.

## How a request travels

```
browser  ->  127.0.0.1:80 or [::1]:80  ->  proxy-caddy  ->  grafana:3000
             (published by docker)          (Host header)   (docker network)
```

Caddy reaches a target the way any container reaches another: by container name,
over that stack's network. The target does **not** need a published port. Both
loopback families are published because a browser tries `::1` first.

## Adding a service

Three steps, and the third is the one that is easy to miss.

1. Give the target stack's network a fixed name, if it does not have one.
   `../observability/docker-compose.yml` shows it: `name: observability` under
   `networks:`. Without it, compose prefixes the project name and the address
   changes with the directory.
2. Attach the proxy to that network. Add it under `networks:` on the `caddy`
   service **and** to the top-level `networks:` block as `external: true` in
   `docker-compose.yml`, then to the loop in `up.sh`.
3. Add the route to `caddy/Caddyfile`:

   ```
   http://<name>.localhost {
   	reverse_proxy <container-service>:<port>
   }
   ```

Then `docker exec proxy-caddy caddy reload -c /etc/caddy/Caddyfile`. A reload is
enough because the mount is the `caddy/` **directory**, not the single file — a
single-file mount serves the old inode after an editor rewrites the file, which
is the trap documented in `../observability/README.md`.

Recreate instead when you touch `docker-compose.yml`:

```sh
docker compose -p proxy -f docker-compose.yml up -d --force-recreate
```

## Notes

**The proxy starts after its tenants.** Every network here is `external`, so
compose refuses to create the container while one of them is missing. `up.sh`
checks first and names the stack to start. Nothing depends on the proxy in the
other direction — the observability stack neither knows nor cares that it exists.

**No HTTPS, on purpose.** Every site address carries an explicit `http://`,
which is what keeps Caddy from issuing an internal-CA certificate and
redirecting to 443. The traffic never leaves the machine, and the alternative is
a browser warning per service plus a CA to install.

**Port 80 is the shared resource.** It is the whole point — a browser hides that
port and no other. One program on the machine can hold it, so a second proxy is
not an option; add a route here instead.

**A 404 from `loki.localhost/` or `tempo.localhost/` is the target's answer, not
a missing route.** Neither serves anything at `/`. Try `/ready` and
`/api/echo`. A route that is genuinely missing says so in words — see the
catch-all at the end of `caddy/Caddyfile`.

**Still loopback-only.** Both published ports bind a loopback address, like
every other stack in this repo. Caddy has no authentication and neither does
anything behind it.
