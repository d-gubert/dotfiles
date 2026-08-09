#!/usr/bin/env bash
#
# Sourced, not executed. Keeps a profile's published ports off host ports that
# something else already holds.
#
# A `ports` file names a fixed host port, and a fixed host port is a shared
# resource: a dev server started outside the container, an unrelated docker
# stack, or a second workspace of the same profile can hold it first. Compose
# then fails the create with "port is already allocated" and you get no container
# at all — for a port you may not even care about. `ports_resolve` moves the
# *host* side of such a mapping to the next free port and warns. The container
# port never changes, so nothing inside the container has to know.
#
# Deliberately not rewritten:
#
#   3000            a bare container port — docker already picks a free host port
#   3000-3005:...   a range; which port of it is the interesting one is the
#                   profile's business, not this file's
#
# The host port this workspace's own container already publishes does not count
# as taken: `up` on a running container has to resolve to the mapping it is
# already running with, or every start would walk the port one further.

# How far above a taken port to look for a free one. Small on purpose: a mapping
# that lands 60 ports away from what the profile asked for is a surprise either
# way, and the warning is the useful part.
_ports_search_span=64

_ports_warn() { printf '\033[1;33m[devbox:ports] WARNING:\033[0m %s\n' "$*" >&2; }

# Every port with a listening socket on the host, one per line.
#
# `ss` sees both what a host process holds and — on a default docker install,
# where the userland proxy is on — the docker-proxy socket of a published
# container port. It is not the whole story: with `userland-proxy: false` a
# published port is iptables DNAT and has no socket at all, which is why
# _ports_from_docker_ps exists as well.
_ports_listening() {
	if command -v ss >/dev/null 2>&1; then
		ss -Hltun 2>/dev/null | awk '{ print $5 }'
	elif command -v netstat >/dev/null 2>&1; then
		netstat -ltun 2>/dev/null | awk '$1 ~ /^(tcp|udp)/ { print $4 }'
	fi |
		# The local address, whatever its shape — 0.0.0.0:3000, [::]:3000,
		# 127.0.0.53%lo:53 — ends in :<port>.
		awk -F: '$NF ~ /^[0-9]+$/ { print $NF }'
}

# Every host port docker publishes, one per line. Extra `docker ps` arguments
# (a --filter) are passed through.
#
# `{{.Ports}}` is a comma-separated list of `0.0.0.0:3000->3000/tcp` for a
# published port and a bare `3000/tcp` for one that is only exposed; the `->`
# test is what tells them apart. A published *range* prints as `3000-3005->...`
# and is skipped by the numeric test — see the header.
_ports_from_docker_ps() {
	command -v docker >/dev/null 2>&1 || return 0
	docker ps "$@" --format '{{.Ports}}' 2>/dev/null |
		tr ',' '\n' |
		awk -F'->' 'NF == 2 { n = split($1, a, ":"); if (a[n] ~ /^[0-9]+$/) print a[n] }'
}

# ports_resolve — `host:container` specs on stdin, the resolved specs on stdout,
# one per line, in the order they came in. Warnings go to stderr.
ports_resolve() {
	local -A busy=()
	local port line rest ip host container proto free candidate

	while read -r port; do
		busy["$port"]=1
	done < <(
		_ports_listening
		_ports_from_docker_ps
	)

	# This workspace's own published ports, subtracted again: they are "in use"
	# precisely because the container we are about to bring up is the one using
	# them.
	if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
		while read -r port; do
			unset "busy[$port]"
		done < <(_ports_from_docker_ps --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME")
	fi

	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue

		rest="$line"
		proto=""
		case "$rest" in
		*/*) proto="/${rest#*/}" rest="${rest%%/*}" ;;
		esac

		# An optional address to bind to, bracketed when it is IPv6. Kept with its
		# trailing colon, so reassembly is just concatenation.
		ip=""
		case "$rest" in
		\[*\]:*) ip="${rest%%]:*}]:" rest="${rest#*]:}" ;;
		*:*:*) ip="${rest%%:*}:" rest="${rest#*:}" ;;
		esac

		case "$rest" in
		*:*) host="${rest%%:*}" container="${rest#*:}" ;;
		*)
			# A bare container port: docker publishes it on a free ephemeral port
			# of its own choosing, so there is nothing here to clash.
			printf '%s\n' "$line"
			continue
			;;
		esac

		# A port range on the host side, or something this parser does not
		# understand. Pass it through and let compose have the last word.
		case "$host" in
		'' | *[!0-9]*)
			printf '%s\n' "$line"
			continue
			;;
		esac

		if [ -z "${busy[$host]:-}" ]; then
			# Claimed even when it is unchanged, so a later line of the same file
			# cannot be moved on top of it.
			busy["$host"]=1
			printf '%s\n' "$line"
			continue
		fi

		free=""
		for ((candidate = host + 1; candidate <= host + _ports_search_span && candidate <= 65535; candidate++)); do
			[ -n "${busy[$candidate]:-}" ] && continue
			free="$candidate"
			break
		done

		if [ -z "$free" ]; then
			_ports_warn "host port $host is in use and so is everything up to $((host + _ports_search_span)) — publishing $line anyway"
			printf '%s\n' "$line"
			continue
		fi

		busy["$free"]=1
		_ports_warn "host port $host is already in use — publishing $free:$container instead of $line"
		printf '%s\n' "$ip$free:$container$proto"
	done
}
