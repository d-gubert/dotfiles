#!/bin/bash
set -Eeuo pipefail  # Exit on error (incl. inside functions), undefined vars, pipe failures
IFS=$'\n\t'        # Stricter word splitting

# Default-deny egress firewall for the devbox container.
# Adapted from the Claude Code reference:
#   https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh
#
# What may be reached is *data*, not code: the allowlist is assembled from
# ../../allowed-domains (the floor), each declared feature's own
# ../<feature>/allowed-domains, the matched profile's
# ../../projects/<profile>/allowed-domains, and DEVBOX_ALLOW_DOMAINS. A repo that
# needs its own hosts adds them in its profile, never in here.
#
# Design notes (differences from the reference script):
#   * The allowlist is resolved FIRST and the iptables rules are applied LAST, in
#     one go, so a transient DNS/network hiccup can never leave the container
#     half-firewalled.
#   * No single lookup is fatal. The reference script aborts if api.github.com is
#     unreachable; on a flaky network — or when postStartCommand wins the race
#     against Docker's embedded resolver — that killed the whole run with
#     `curl: (6) Could not resolve host` and left the container with no working
#     egress policy. Here DNS is waited for, every fetch retries, GitHub falls
#     back to its published static ranges, and the firewall is applied regardless.
#   * IPv6 is denied outright — the allowlist is IPv4-only, so leaving ip6tables
#     open would be a trivial bypass of the whole policy.

log() { echo "[firewall] $*"; }
warn() { echo "[firewall] WARNING: $*" >&2; }
die() { echo "[firewall] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root (use sudo)"
for bin in iptables ip6tables ipset dig curl jq aggregate; do
    command -v "$bin" >/dev/null || die "missing required tool: $bin"
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scripts_dir="$(cd "$here/.." && pwd)"
devbox_home="$(cd "$scripts_dir/.." && pwd)"
profile="${DEVBOX_PROFILE:-default}"

# Which scripts/<feature>/ directories are active, so a feature's own allowlist
# only counts while devcontainer.json declares it. Sourced, not executed.
source "$scripts_dir/lib/features.sh"

# Retry helper: retry <attempts> <sleep-seconds> <command...>
retry() {
    local attempts=$1 delay=$2 n=1
    shift 2
    until "$@"; do
        if [ "$n" -ge "$attempts" ]; then
            return 1
        fi
        n=$((n + 1))
        sleep "$delay"
    done
}

# Every allowed IP/CIDR is collected here first; nothing is applied until the
# list is complete (or we give up on completing it).
ALLOWED_CIDRS=$(mktemp)
trap 'rm -f "$ALLOWED_CIDRS"' EXIT

# ---------------------------------------------------------------------------
# The apply step. Purely local — no network calls — so once we get here it
# either fully succeeds or fails for a reason retrying would not fix.
# ---------------------------------------------------------------------------
FIREWALL_APPLIED=0

apply_firewall() {
    # Build into a temp set and swap it in, so the live set is replaced
    # atomically and re-runs never trip over "set with the same name exists".
    ipset destroy allowed-domains-new 2>/dev/null || true
    ipset create allowed-domains-new hash:net
    while read -r entry; do
        [ -n "$entry" ] || continue
        ipset add -exist allowed-domains-new "$entry"
    done <"$ALLOWED_CIDRS"

    if ipset list -n allowed-domains >/dev/null 2>&1; then
        ipset swap allowed-domains-new allowed-domains
        ipset destroy allowed-domains-new
    else
        ipset rename allowed-domains-new allowed-domains
    fi

    # Flush only the FILTER table — our firewall lives entirely there. We
    # deliberately do NOT touch nat/mangle: flushing nat wipes Docker's
    # embedded-DNS redirect (127.0.0.11) and the save/restore workaround for that
    # is fragile and was leaving DNS resolution broken inside the container.
    # Leaving nat/mangle alone keeps Docker DNS (and sibling-service resolution)
    # working.
    iptables -F
    iptables -X

    # DNS. Docker's embedded resolver lives on 127.0.0.11 (reached over lo), but
    # allow 53 outright so a plain /etc/resolv.conf nameserver also works. TCP/53
    # matters for responses too large for UDP.
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -j ACCEPT

    # SSH out (git over ssh), plus loopback.
    iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Every docker network this container is attached to, in BOTH directions.
    #
    # That is its own compose bridge — which carries forwarded-port traffic back
    # from the host and any sibling service a profile adds — plus each network a
    # profile joins as external: the shared MongoDB, the observability stack.
    # Those are all declared by this repo's own compose files, so a container on
    # one of them is trusted the same way a sibling on the bridge always was.
    #
    # INPUT and not only OUTPUT because some of them start the conversation:
    # Prometheus opens the connection to scrape /metrics, and an INPUT policy of
    # DROP would leave the scrape timing out with nothing in any log to say why.
    #
    # Read out of the routing table, not derived from the default route. With
    # several networks attached, which one gets the default route is decided by
    # the order Docker connected them — so a profile that joins one more network
    # could move it, and the old rule would then cover a network the container
    # barely uses while leaving its own bridge, and with it every forwarded port,
    # firewalled off. `scope link` is exactly the set of directly reachable
    # subnets, one per attached network.
    local subnet attached=0
    while read -r subnet; do
        [ -n "$subnet" ] || continue
        log "attached network: $subnet"
        iptables -A INPUT -s "$subnet" -j ACCEPT
        iptables -A OUTPUT -d "$subnet" -j ACCEPT
        attached=1
    done < <(ip -4 route show scope link | awk '$1 ~ /\// { print $1 }' | sort -u)
    if [ "$attached" -eq 0 ]; then
        warn "no attached networks found — the host and sibling services will be unreachable"
    fi

    # Established connections for already-approved traffic.
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # The allowlist itself.
    iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

    # REJECT rather than DROP so blocked calls fail fast instead of hanging.
    iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

    # The allowlist is IPv4-only; without this, any host with an AAAA record
    # stays reachable and the whole policy is trivially bypassed.
    ip6tables -F
    ip6tables -X
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP

    FIREWALL_APPLIED=1
}

# Any unexpected failure during setup must still leave a firewall behind rather
# than a wide-open container.
on_error() {
    local rc=$?
    trap - ERR  # don't recurse if apply_firewall is what blew up
    warn "setup failed (exit $rc) — applying default-deny with the allowlist gathered so far"
    if [ "$FIREWALL_APPLIED" -eq 0 ]; then
        apply_firewall || warn "could not apply firewall rules"
    fi
    exit "$rc"
}
trap on_error ERR

# ---------------------------------------------------------------------------
# Phase 0 — open the box up so the lookups below can run.
# ---------------------------------------------------------------------------
# `iptables -F` clears rules but NOT the policy, so a lingering DROP from a
# previous run (postStartCommand runs on every container start) would otherwise
# block the DNS/GitHub lookups this script depends on.
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT

# ---------------------------------------------------------------------------
# Phase 1 — wait for DNS.
# ---------------------------------------------------------------------------
# postStartCommand fires the moment the container is up, which can be before
# Docker's embedded resolver (127.0.0.11) is answering.
#
# Every lookup below is explicitly time-boxed (`dig +time/+tries`, curl
# --max-time). This script runs on the critical path of every container start,
# so a dead resolver has to cost seconds, not the many minutes that dig's default
# timeouts add up to across a couple of dozen domains.
#
# `dig +short` prints its diagnostics (";; no servers could be reached") to
# STDOUT, and exits 0 on an empty/NXDOMAIN answer — so the only reliable success
# check is "did we get something shaped like an IPv4 address back".
resolve_a() { dig +short +time=2 +tries=1 A "$1" 2>/dev/null | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; }

dns_up() { [ -n "$(resolve_a registry.npmjs.org)" ]; }

log "waiting for DNS..."
DNS_READY=1
if retry 10 1 dns_up; then
    log "DNS is up"
else
    DNS_READY=0
    warn "DNS still not resolving after ~20s — the allowlist will be incomplete"
fi

# ---------------------------------------------------------------------------
# Phase 2 — build the allowlist (nothing here touches iptables).
# ---------------------------------------------------------------------------

# GitHub's stable published prefixes, used when api.github.com/meta is
# unreachable. The hostnames in the allowlist files cover the Azure-hosted
# endpoints (api.github.com et al.) that live outside these blocks.
GITHUB_FALLBACK_RANGES="192.30.252.0/22
185.199.108.0/22
140.82.112.0/20
143.55.64.0/20"

log "fetching GitHub IP ranges..."
gh_meta=$(mktemp)
gh_ranges=""
if [ "$DNS_READY" -eq 1 ] \
    && retry 2 2 curl -fsS --connect-timeout 5 --max-time 15 -o "$gh_meta" https://api.github.com/meta \
    && jq -e '.web and .api and .git' "$gh_meta" >/dev/null 2>&1; then
    gh_ranges=$(jq -r '(.web + .api + .git)[]' "$gh_meta" | grep -E '^[0-9.]+/[0-9]+$' | aggregate -q) || gh_ranges=""
fi
rm -f "$gh_meta"

if [ -z "$gh_ranges" ]; then
    warn "could not fetch api.github.com/meta — falling back to GitHub's static ranges"
    gh_ranges="$GITHUB_FALLBACK_RANGES"
fi

while read -r cidr; do
    [ -n "$cidr" ] || continue
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        warn "skipping invalid CIDR from GitHub meta: $cidr"
        continue
    fi
    echo "$cidr" >>"$ALLOWED_CIDRS"
done < <(echo "$gh_ranges")
log "collected $(wc -l <"$ALLOWED_CIDRS") GitHub ranges"

# --- The allowlist files ------------------------------------------------------
#
# Four sources, in order of increasing specificity. Each is optional except the
# base file, and each is announced so the container's start-up log says exactly
# what the policy was built from.
ALLOWED_DOMAINS=()

# read_list <file> <label> — appends the file's non-comment entries. An IP or
# CIDR goes straight into the ipset; anything else is a name to resolve below.
read_list() {
    local file="$1" label="$2" line count=0
    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] || continue
        if [[ "$line" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
            echo "$line" >>"$ALLOWED_CIDRS"
        else
            ALLOWED_DOMAINS+=("$line")
        fi
        count=$((count + 1))
    done <"$file"
    log "allowlist: $count entr$([ "$count" = 1 ] && echo y || echo ies) from $label"
}

read_list "$devbox_home/allowed-domains" "the base list"

# Feature lists. `feature_dir_enabled` is false for a feature commented out of
# devcontainer.json, so its hosts drop out of the policy with it.
for dir in "$scripts_dir"/*/; do
    dir="${dir%/}"
    [ -f "$dir/allowed-domains" ] || continue
    if feature_dir_enabled "$dir"; then
        read_list "$dir/allowed-domains" "feature $(basename "$dir")"
    else
        log "allowlist: skipping $(basename "$dir") — its feature is not declared"
    fi
done

read_list "$devbox_home/projects/$profile/allowed-domains" "profile $profile"

# The one-off escape hatch, for trying a host out before deciding it belongs in a
# profile: DEVBOX_ALLOW_DOMAINS="a.example b.example" devbox up
if [ -n "${DEVBOX_ALLOW_DOMAINS:-}" ]; then
    env_list=$(mktemp)
    printf '%s' "$DEVBOX_ALLOW_DOMAINS" | tr ', ' '\n\n' >"$env_list"
    read_list "$env_list" "DEVBOX_ALLOW_DOMAINS"
    rm -f "$env_list"
fi

# A domain that fails to resolve warns and continues rather than aborting
# startup: the firewall still applies default-deny, just without that host.
if [ "$DNS_READY" -eq 0 ]; then
    warn "skipping domain resolution — no working resolver"
elif [ ${#ALLOWED_DOMAINS[@]} -eq 0 ]; then
    warn "no domains to resolve — is $devbox_home/allowed-domains readable?"
else
    unresolved=()
    for domain in "${ALLOWED_DOMAINS[@]}"; do
        ips=$(retry 2 1 resolve_a "$domain") || ips=""
        if [ -z "$ips" ]; then
            unresolved+=("$domain")
            continue
        fi
        while read -r ip; do
            [ -n "$ip" ] || continue
            echo "$ip" >>"$ALLOWED_CIDRS"
        done < <(echo "$ips")
    done

    if [ ${#unresolved[@]} -gt 0 ]; then
        # IFS is newline/tab, so join explicitly to keep this on one line.
        warn "could not resolve, skipping: $(IFS=,; echo "${unresolved[*]}")"
    fi
fi
log "allowlist contains $(wc -l <"$ALLOWED_CIDRS") entries"

# ---------------------------------------------------------------------------
# Phase 3 — apply.
# ---------------------------------------------------------------------------
apply_firewall
trap - ERR
log "firewall configuration complete"

# ---------------------------------------------------------------------------
# Phase 4 — verify. Only a leak is fatal; an expected-but-blocked host is a
# warning, so a flaky network can't turn every container start into a red error.
# ---------------------------------------------------------------------------
log "verifying firewall rules..."
if curl --connect-timeout 5 -sI https://example.com >/dev/null 2>&1; then
    die "verification failed — https://example.com is reachable, the firewall is not blocking"
fi
log "verified: https://example.com is blocked as expected"

for url in https://api.github.com/zen https://api.anthropic.com https://registry.npmjs.org/; do
    if curl --connect-timeout 5 -sI "$url" >/dev/null 2>&1; then
        log "verified: $url is reachable"
    else
        warn "$url is NOT reachable — tooling that needs it will fail"
    fi
done
