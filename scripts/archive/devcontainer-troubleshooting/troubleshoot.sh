#!/usr/bin/env bash
# Dev container diagnostics. Run from the HOST, not inside the container.
#
#   ./.devcontainer/troubleshoot.sh            # everything except profile
#   ./.devcontainer/troubleshoot.sh drift      # is the container running your edits?
#   ./.devcontainer/troubleshoot.sh mounts     # volume mounts, ownership, host-path leaks
#   ./.devcontainer/troubleshoot.sh firewall   # egress policy + whether it is blocking anything
#   ./.devcontainer/troubleshoot.sh hang [pid] # is a busy process progressing or spinning?
#   ./.devcontainer/troubleshoot.sh profile [pid]  # attach Node inspector, print hottest stacks
#
# Env overrides:
#   RC_CONTAINER=<name>   skip container auto-detection
#   RC_SAMPLE=<seconds>   sampling window for `hang` (default 30)
#   RC_PROFILE=<seconds>  profile duration for `profile` (default 15)
set -Eeuo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEVC="$REPO_ROOT/.devcontainer"
WS=/workspaces/rocket.chat
SAMPLE="${RC_SAMPLE:-30}"
PROFILE_SECS="${RC_PROFILE:-15}"

ok()   { printf '  [ OK ] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; }
info() { printf '         %s\n' "$*"; }
head_() { printf '\n=== %s ===\n' "$*"; }

# --- container discovery ----------------------------------------------------
# Match the compose `app` service whose image is a devcontainer-CLI build
# (vsc-*), so a stray app service from another project is not picked up.
detect_container() {
    if [ -n "${RC_CONTAINER:-}" ]; then echo "$RC_CONTAINER"; return; fi
    docker ps --filter 'label=com.docker.compose.service=app' \
              --format '{{.Names}}\t{{.Image}}' \
        | awk -F'\t' '$2 ~ /^vsc-/ {print $1; exit}'
}

CONTAINER=$(detect_container || true)
if [ -z "$CONTAINER" ]; then
    bad "no running devcontainer 'app' service found"
    info "start it with: npx @devcontainers/cli up --workspace-folder ."
    info "or set RC_CONTAINER=<name>"
    exit 1
fi

dex()  { docker exec "$CONTAINER" "$@"; }
dexb() { docker exec "$CONTAINER" bash -c "$1"; }

# ---------------------------------------------------------------------------
# 1. DRIFT — always run this first.
#
# The single most expensive mistake in this repo is debugging a container that
# predates your edits. `devcontainer up` ATTACHES to an existing container and
# skips the build entirely, so re-running it after editing the Dockerfile is a
# no-op. Nothing below is trustworthy until this section is clean.
# ---------------------------------------------------------------------------
check_drift() {
    head_ "1. Config drift (is the container running your edits?)"

    local created epoch newer
    created=$(docker inspect -f '{{.Created}}' "$CONTAINER")
    epoch=$(date -d "$created" +%s)
    info "container : $CONTAINER"
    info "created   : $(date -u -d "$created" '+%Y-%m-%d %H:%M:%S UTC')"
    info "image     : $(docker inspect -f '{{.Config.Image}}' "$CONTAINER" | cut -c1-60)"

    # Only files that actually shape the image or the container count here;
    # docs and this script itself are not baked in.
    newer=$(find "$DEVC" -maxdepth 1 -type f -newermt "@$epoch" \
        \( -name Dockerfile -o -name devcontainer.json -o -name docker-compose.yml -o -name init-firewall.sh \) \
        -printf '%f ' 2>/dev/null || true)
    if [ -n "$newer" ]; then
        bad "config edited after the container was created: $newer"
        info "=> recreate: npx @devcontainers/cli up --workspace-folder . --remove-existing-container"
    else
        ok "no .devcontainer file is newer than the container"
    fi

    # Content check, independent of timestamps: the firewall script is COPYed
    # into the image, so image and working tree must agree byte for byte.
    local want have
    want=$(md5sum "$DEVC/init-firewall.sh" | cut -d' ' -f1)
    have=$(dex md5sum /usr/local/bin/rc-init-firewall.sh 2>/dev/null | cut -d' ' -f1 || echo missing)
    if [ "$want" = "$have" ]; then
        ok "rc-init-firewall.sh matches the working tree ($want)"
    else
        bad "firewall script differs — image=$have working-tree=$want"
    fi

    # The claude-code feature installs its own /usr/local/bin/init-firewall.sh
    # over ours. Ours is deliberately rc-prefixed; verify nothing reintroduced
    # the collision by pointing postStartCommand back at the unprefixed name.
    if grep -q 'rc-init-firewall.sh' "$DEVC/devcontainer.json"; then
        ok "postStartCommand targets the rc-prefixed script"
    else
        bad "devcontainer.json does not reference rc-init-firewall.sh — the"
        info "claude-code feature will silently overwrite the unprefixed name"
    fi

    # ENV declared in the Dockerfile must actually be present in the image.
    # Values referencing other variables (notably PATH) are skipped: the image
    # stores them expanded, so a literal comparison is meaningless.
    local k v
    while IFS='=' read -r k v; do
        [ -n "$k" ] || continue
        case "$v" in *'$'*) continue ;; esac
        local actual
        actual=$(dexb "printf '%s' \"\${$k:-}\"")
        if [ "$actual" = "$v" ]; then
            ok "$k=$actual"
        else
            bad "$k: image has '${actual:-<unset>}', Dockerfile declares '$v'"
        fi
    done < <(grep -oP '^ENV \K[A-Z_]+="[^"]+"' "$DEVC/Dockerfile" 2>/dev/null | tr -d '"' || true)
}

# ---------------------------------------------------------------------------
# 2. MOUNTS — named volumes mount root:root, and bind mounts leak host paths.
# ---------------------------------------------------------------------------
check_mounts() {
    head_ "2. Mounts, ownership and host-path leaks"

    local p src owner
    for p in "$WS/node_modules" "$WS/apps/meteor/.meteor/local"; do
        if ! dexb "test -d '$p'" 2>/dev/null; then
            warn "$p does not exist in the container"
            continue
        fi
        src=$(dexb "findmnt -no SOURCE '$p' 2>/dev/null || echo '(not a mount)'")
        owner=$(dexb "stat -c '%u:%g' '$p'")
        case "$src" in
            *"(not a mount)"*)
                bad "$p is NOT a separate mount — it is on the host bind mount"
                info "host and container will fight over absolute paths written here" ;;
            *) ok "$p <- ${src##*volumes/}" ;;
        esac
        if [ "$owner" = "1000:1000" ]; then
            ok "  owner $owner (vscode)"
        else
            bad "  owner $owner — vscode cannot write here (empty named volumes mount root:root)"
            info "  fix in postCreateCommand: sudo chown vscode:vscode $p"
        fi
    done

    # Broken symlinks are the fingerprint of host state leaking in: Meteor and
    # friends write ABSOLUTE paths (e.g. .meteor/local/dev_bundle ->
    # /home/<hostuser>/.meteor/...) which cannot resolve inside the container.
    head_ "2b. Broken symlinks in the workspace (host-path leaks)"
    local broken
    broken=$(dexb "find '$WS' -maxdepth 5 \\( -name node_modules -o -name .git \\) -prune -o -xtype l -print 2>/dev/null | head -20" || true)
    if [ -z "$broken" ]; then
        ok "no broken symlinks found"
    else
        bad "broken symlinks (host paths that do not exist in the container):"
        while read -r l; do
            [ -n "$l" ] || continue
            info "$l -> $(dexb "readlink '$l'")"
        done <<<"$broken"
        info "=> move the offending directory onto its own named volume"
    fi
}

# ---------------------------------------------------------------------------
# 3. FIREWALL — distinguish "policy is on" from "policy is blocking me".
#
# The script REJECTs rather than DROPs, so a blocked connection fails in ~1ms
# and never appears in SYN-SENT. Absence of pending connections proves nothing;
# the REJECT packet counter is the real signal.
# ---------------------------------------------------------------------------
check_firewall() {
    head_ "3. Egress firewall"

    if ! dexb 'iptables -L OUTPUT -n >/dev/null 2>&1'; then
        bad "cannot read iptables (NET_ADMIN missing?)"
        return
    fi

    local policy setsize r1 r2
    policy=$(dexb "iptables -L OUTPUT -n | head -1")
    info "$policy"
    case "$policy" in
        *"policy DROP"*) ok "default-deny is active" ;;
        *) bad "OUTPUT policy is not DROP — the firewall is not applied" ;;
    esac

    setsize=$(dexb "ipset list allowed-domains 2>/dev/null | awk '/Number of entries/{print \$NF}'" || echo 0)
    if [ "${setsize:-0}" -gt 0 ]; then ok "allowlist has $setsize entries"; else bad "allowlist is empty"; fi

    r1=$(dexb "iptables -L OUTPUT -n -v | awk '/REJECT/{print \$1}'")
    sleep 5
    r2=$(dexb "iptables -L OUTPUT -n -v | awk '/REJECT/{print \$1}'")
    if [ "$r1" = "$r2" ]; then
        ok "REJECT counter static at $r1 over 5s — nothing is being blocked right now"
    else
        warn "REJECT counter $r1 -> $r2 — something IS being blocked"
        info "identify it: docker exec $CONTAINER bash -c 'iptables -I OUTPUT 1 -j LOG --log-prefix \"BLOCKED \"' then check dmesg"
    fi

    head_ "3b. Reachability of allowlisted hosts"
    local url code
    for url in https://api.github.com/zen https://registry.npmjs.org/ https://packages.meteor.com/ https://api.anthropic.com; do
        # Reachability is "did we get an HTTP response", NOT "was it 2xx" — so no
        # -f, which would report a 404/405 from a bare GET as unreachable. A GET
        # rather than -sI: some registries are slow to answer HEAD on a cold
        # connection, and a short HEAD timeout yields false failures.
        # `|| true` INSIDE the substitution: curl already prints 000 on failure,
        # so an `|| echo 000` outside would append a second line and make the
        # comparison below always take the "reachable" branch.
        code=$(dexb "curl -sS --connect-timeout 5 --max-time 20 -o /dev/null -w '%{http_code}' '$url' 2>/dev/null" || true)
        if [ "$code" != "000" ] && [ -n "$code" ]; then ok "$url (HTTP $code)"; else warn "$url unreachable"; fi
    done
    code=$(dexb "curl -sS --connect-timeout 5 -o /dev/null -w '%{http_code}' https://example.com 2>/dev/null" || true)
    if [ "$code" != "000" ] && [ -n "$code" ]; then
        bad "https://example.com is REACHABLE — the firewall is not blocking"
    else
        ok "https://example.com correctly blocked"
    fi
}

# ---------------------------------------------------------------------------
# 4. HANG TRIAGE — is a busy process progressing, blocked, or spinning?
#
# Decision table (deltas over the sampling window):
#   REJECT delta > 0 ................ blocked by the firewall
#   CPU delta ~0, state S/D ......... blocked on I/O, a lock, or the network
#   CPU delta high + no writes,
#     no children, RSS flat/falling . SPINNING  <- the interesting failure
#   CPU delta high + writes/children  progressing, just slow
# ---------------------------------------------------------------------------
check_hang() {
    local pid="${1:-}"
    head_ "4. Hang triage"

    if [ -z "$pid" ]; then
        pid=$(dexb "pgrep -f 'tools/index.js' | head -1" || true)
        [ -n "$pid" ] || pid=$(dexb "pgrep -f 'meteor-tool' | head -1" || true)
    fi
    if [ -z "$pid" ]; then
        ok "no meteor-tool process running — nothing to triage"
        return
    fi
    info "pid $pid: $(dexb "tr '\\0' ' ' < /proc/$pid/cmdline | cut -c1-110" || true)"

    read_cpu()  { dexb "awk '{print \$14+\$15}' /proc/$pid/stat"; }          # ticks
    read_rss()  { dexb "awk '/VmRSS/{print \$2}' /proc/$pid/status"; }       # kB
    read_kids() { dexb "pgrep -P $pid | wc -l"; }
    read_rej()  { dexb "iptables -L OUTPUT -n -v | awk '/REJECT/{print \$1}'"; }
    # Productive output = actual build artefacts. Deliberately EXCLUDES the
    # warehouse package-metadata directory: Meteor churns SQLite journal files
    # there continuously while spinning, so counting it as progress turns the
    # spin into a false "healthy" verdict.
    read_writes() {
        dexb "find $WS/apps/meteor/.meteor /usr/local/meteor/packages -newermt '-${SAMPLE} seconds' 2>/dev/null | head -5"
    }
    read_catalog() {
        dexb "find /usr/local/meteor/package-metadata -newermt '-${SAMPLE} seconds' 2>/dev/null | head -3"
    }

    local c1 r1 k1 j1 c2 r2 k2 j2 dcpu hz pct
    c1=$(read_cpu); r1=$(read_rss); k1=$(read_kids); j1=$(read_rej)
    info "sampling ${SAMPLE}s..."
    sleep "$SAMPLE"
    c2=$(read_cpu); r2=$(read_rss); k2=$(read_kids); j2=$(read_rej)

    hz=$(dexb 'getconf CLK_TCK')
    dcpu=$(( (c2 - c1) * 100 / hz ))          # centi-seconds of CPU
    pct=$(( dcpu / SAMPLE ))                   # ~percent of one core

    info "cpu    : ${pct}% of one core over the window"
    info "rss    : ${r1}kB -> ${r2}kB"
    info "children: $k1 -> $k2"
    info "reject : $j1 -> $j2"
    local writes catalog
    writes=$(read_writes || true)
    catalog=$(read_catalog || true)
    if [ -n "$writes" ]; then info "output : $(echo "$writes" | tr '\n' ' ')"; else info "output : none"; fi
    if [ -n "$catalog" ]; then info "catalog: churning (package-metadata touched)"; fi

    echo
    if [ "$j1" != "$j2" ]; then
        bad "VERDICT: firewall is rejecting packets for this workload"
        info "=> add the host to ALLOWED_DOMAINS in init-firewall.sh, then recreate"
    elif [ "$pct" -lt 5 ]; then
        bad "VERDICT: idle — blocked on I/O, a lock, or the network (not CPU-bound)"
        info "check for a stale Meteor lock: ls -la $WS/apps/meteor/.meteor/local/lock"
    elif [ "$k2" -gt "$k1" ] || [ -n "$writes" ]; then
        ok "VERDICT: progressing (spawned children and/or wrote build output) — just slow"
    elif [ -n "$catalog" ]; then
        bad "VERDICT: SPINNING in the Meteor package catalog"
        info "high CPU, no children, no build output — the only activity is SQLite"
        info "journal churn in package-metadata. A real build grows RSS and emits"
        info "files; this does neither. KNOWN UNRESOLVED ISSUE (see TROUBLESHOOTING.md)"
        info "=> next: $0 profile $pid"
    elif [ "$r2" -le "$r1" ]; then
        bad "VERDICT: SPINNING — high CPU, no output, no children, RSS not growing"
        info "=> next: $0 profile $pid"
    else
        warn "VERDICT: busy, memory growing, but no files or children yet — re-run to confirm"
    fi
}

# ---------------------------------------------------------------------------
# 5. PROFILE — name the function it is looping in.
#
# SIGUSR1 makes Node open its inspector on 127.0.0.1:9229 (loopback only, which
# the firewall allows). This ATTACHES A DEBUGGER to a live process: it does not
# kill it, but it does pause it briefly. Ask before running against someone
# else's session.
# ---------------------------------------------------------------------------
do_profile() {
    local pid="${1:-}"
    head_ "5. CPU profile"
    if [ -z "$pid" ]; then
        pid=$(dexb "pgrep -f 'tools/index.js' | head -1" || true)
    fi
    [ -n "$pid" ] || { bad "no target pid"; return 1; }

    # Signalling the wrong pid wastes a run and silently does nothing: pgrep
    # readily matches transient shells. Confirm the target is really Node.
    if ! dexb "tr '\\0' ' ' < /proc/$pid/cmdline 2>/dev/null | grep -q node"; then
        bad "pid $pid is not a node process — SIGUSR1 will not open an inspector"
        info "candidates: $(dexb "pgrep -a node 2>/dev/null | head -5" || true)"
        return 1
    fi

    info "opening inspector on pid $pid (SIGUSR1)"
    dexb "kill -USR1 $pid" || { bad "could not signal $pid"; return 1; }
    sleep 2

    if ! dexb 'curl -fsS --max-time 5 http://127.0.0.1:9229/json/list >/dev/null'; then
        bad "inspector did not open on 127.0.0.1:9229"
        info "the process may already have an inspector, or is not Node"
        return 1
    fi
    ok "inspector is listening"

    docker exec -i "$CONTAINER" bash -c 'cat > /tmp/rc-prof.mjs' <<'NODEJS'
// Minimal CDP client: record a CPU profile and print the hottest frames by
// SELF time. Uses Node 22 globals (fetch, WebSocket) so nothing to install.
const secs = Number(process.argv[2] || 15);
const res = await fetch('http://127.0.0.1:9229/json/list');
const target = (await res.json()).find(t => t.webSocketDebuggerUrl);
if (!target) { console.error('no debuggable target'); process.exit(1); }

const ws = new WebSocket(target.webSocketDebuggerUrl);
let seq = 0;
const pending = new Map();
const send = (method, params = {}) =>
  new Promise(resolve => { const id = ++seq; pending.set(id, resolve); ws.send(JSON.stringify({ id, method, params })); });

ws.addEventListener('message', ev => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result); pending.delete(msg.id); }
});

ws.addEventListener('open', async () => {
  await send('Profiler.enable');
  await send('Profiler.setSamplingInterval', { interval: 1000 });
  await send('Profiler.start');
  console.error(`recording ${secs}s...`);
  await new Promise(r => setTimeout(r, secs * 1000));
  const { profile } = await send('Profiler.stop');

  const self = new Map();
  for (let i = 0; i < profile.samples.length; i++) {
    const id = profile.samples[i];
    self.set(id, (self.get(id) || 0) + (profile.timeDeltas[i] || 0));
  }
  const frames = new Map(profile.nodes.map(n => [n.id, n.callFrame]));
  const total = [...self.values()].reduce((a, b) => a + b, 0) || 1;

  // console.log does NOT honour printf width specifiers (%-8s); pad manually.
  console.log('\n' + 'self(ms)'.padEnd(10) + 'pct'.padEnd(8) + 'function');
  [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, 20).forEach(([id, us]) => {
    const f = frames.get(id) || {};
    const where = f.url ? `${String(f.url).replace(/^file:\/\//, '')}:${(f.lineNumber ?? 0) + 1}` : '';
    const name = f.functionName || '(anonymous)';
    const pct = ((us / total) * 100).toFixed(1) + '%';
    console.log((us / 1000).toFixed(0).padEnd(10) + pct.padEnd(8) + `${name}  ${where}`);
  });
  ws.close();
  process.exit(0);
});
NODEJS

    dex node /tmp/rc-prof.mjs "$PROFILE_SECS"
}

case "${1:-all}" in
    drift)    check_drift ;;
    mounts)   check_mounts ;;
    firewall) check_firewall ;;
    hang)     check_hang "${2:-}" ;;
    profile)  do_profile "${2:-}" ;;
    all)      check_drift; check_mounts; check_firewall; check_hang "${2:-}" ;;
    *)        sed -n '2,18p' "$0"; exit 1 ;;
esac
