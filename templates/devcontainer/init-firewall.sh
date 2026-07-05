#!/bin/bash
# Locks outbound network down to an allowlist: DNS, SSH, the host LAN, GitHub's
# published ranges, and the domains listed below. Everything else is dropped.
# This is what makes running Claude with permissions bypassed safe inside the
# container — an agent physically cannot reach an arbitrary host to exfiltrate.
#
# Add domains your projects legitimately need to the ALLOWED_DOMAINS list.
set -euo pipefail
IFS=$'\n\t'

# ── Domains allowed outbound in addition to GitHub. Edit as needed. ──────────
# NOTE: these resolve to fixed IPs at firewall-setup time. Hosts behind a CDN
# (Fastly/CloudFront) rotate IPs, so if a download starts failing later, just
# re-run this script: `sudo /usr/local/bin/init-firewall.sh`.
ALLOWED_DOMAINS=(
  # Core: package registries + Anthropic/telemetry
  "registry.npmjs.org"
  "registry.yarnpkg.com"
  "api.anthropic.com"
  "sentry.io"
  "statsig.anthropic.com"
  "statsig.com"

  # GitHub release assets / raw content (Fastly, not in api.github.com/meta)
  "objects.githubusercontent.com"
  "raw.githubusercontent.com"
  "codeload.github.com"

  # Meteor: CLI package server, warehouse, login, Atmosphere packages
  "packages.meteor.com"
  "warehouse.meteor.com"
  "authentication.meteor.com"
  "static.meteor.com"
  "atmospherejs.com"
  "api.atmospherejs.com"
  "packages.atmospherejs.com"

  # Rocket.Chat
  "releases.rocket.chat"
  "download.rocket.chat"
)

# Flush existing rules and ipsets.
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# Allow DNS, SSH, and localhost before applying the default-drop policy.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

# GitHub's published IP ranges (web + api + git).
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
  echo "ERROR: Failed to fetch GitHub IP ranges"
  exit 1
fi
if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
  echo "ERROR: GitHub API response missing required fields"
  exit 1
fi
echo "Processing GitHub IPs..."
while read -r cidr; do
  if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
    exit 1
  fi
  echo "Adding GitHub range $cidr"
  ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve and allow each configured domain. A domain that doesn't resolve is a
# warning, not a fatal error — the list is curated but may include hosts a given
# project doesn't use, and we don't want that to block container creation.
for domain in "${ALLOWED_DOMAINS[@]}"; do
  echo "Resolving $domain..."
  # Keep only IPv4 lines — dig returns CNAME target hostnames too for CDN-fronted
  # domains, which would otherwise fail the IP check below.
  ips=$(dig +short A "$domain" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true)
  if [ -z "$ips" ]; then
    echo "WARNING: Failed to resolve $domain — skipping"
    continue
  fi
  while read -r ip; do
    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      echo "ERROR: Invalid IP from DNS for $domain: $ip"
      exit 1
    fi
    echo "Adding $ip for $domain"
    ipset add allowed-domains "$ip"
  done < <(echo "$ips")
done

# Allow the host LAN (so the VS Code / editor bridge keeps working).
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
  echo "ERROR: Failed to detect host IP"
  exit 1
fi
HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Default-drop everything, then permit established connections and the allowlist.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Verify: an off-list host must fail, an on-list host must succeed.
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "ERROR: Firewall verification failed - was able to reach https://example.com"
  exit 1
else
  echo "Firewall verification passed - unable to reach https://example.com as expected"
fi
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
  echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
  exit 1
else
  echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

echo "Firewall configuration complete"
