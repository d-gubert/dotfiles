#!/usr/bin/env bash
#
# Find the running Rocket.Chat dev servers and report the facts a recording needs:
# the port, the Mongo connection string, the directory the server runs from, and the version.
#
# Why this exists: `ss -ltnp` says that a port is busy, but not which code, database or version is
# behind it. The platform layer reads each candidate process's own environment instead of guessing.
#
# Usage:
#   find-server.sh                 # human table of every server found
#   find-server.sh --env           # shell assignments for the server to use; exit 1 if none
#   find-server.sh --env --port N  # the same, for the server on port N
#   find-server.sh --json          # one JSON object per server
#
# One running server is used as it is, wherever it runs from. When several run, --env picks the one
# that runs from the current checkout. When that is still ambiguous it lists them and asks for
# --port, rather than drive the wrong code.
#
set -uo pipefail

MODE=table
WANT_PORT=''

while [ $# -gt 0 ]; do
	case "$1" in
	--env) MODE=env; shift ;;
	--json) MODE=json; shift ;;
	--table) MODE=table; shift ;;
	--port)
		WANT_PORT=${2:-}
		[ -n "$WANT_PORT" ] || { echo 'find-server.sh: --port needs a number.' >&2; exit 2; }
		shift 2
		;;
	-h | --help)
		sed -n '2,17p' "$0"
		exit 0
		;;
	*)
		echo "find-server.sh: unknown argument '$1'" >&2
		exit 2
		;;
	esac
done

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# How to read a process's own environment is platform work; the platform layer does it.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform.sh"
if [ -z "$PLATFORM_ID" ]; then
	echo "find-server.sh: $(platform_unsupported_message)" >&2
	exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')

candidates=$(platform_list_server_processes)
if [ -n "$WANT_PORT" ] && [ -n "$candidates" ]; then
	candidates=$(printf '%s\n' "$candidates" | awk -F'|' -v p="$WANT_PORT" '$1 == p')
fi

if [ -z "$candidates" ]; then
	case "$MODE" in
	env) echo "SERVER_FOUND=0" ;;
	json) echo '[]' ;;
	table) echo "No Rocket.Chat dev server is running${WANT_PORT:+ on port $WANT_PORT}." ;;
	esac
	[ "$MODE" = table ] || echo "find-server.sh: no Rocket.Chat dev server is running${WANT_PORT:+ on port $WANT_PORT}." >&2
	exit 1
fi

# Ask each server for its own version. A process can be mid-build and not answer yet.
probe_version() {
	curl -s -m 5 "http://localhost:$1/api/info" 2>/dev/null |
		sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1
}

ports=()
mongos=()
dirs=()
branches=()
versions=()
currents=()

while IFS='|' read -r port mongo app_pwd pid; do
	[ -n "$port" ] || continue
	dir=${app_pwd%/apps/meteor}
	version=$(probe_version "$port")
	[ -n "$version" ] || version='(no answer)'
	current=no
	if [ -n "$REPO_ROOT" ] && [ "$dir" = "$REPO_ROOT" ]; then
		current=yes
	fi
	ports+=("$port")
	mongos+=("$mongo")
	dirs+=("$dir")
	branches+=("$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')")
	versions+=("$version")
	currents+=("$current")
done <<<"$candidates"

print_table() {
	printf '%-5s %-11s %-31s %s\n' PORT VERSION BRANCH DIRECTORY
	local i
	for i in "${!ports[@]}"; do
		printf '%-5s %-11s %-31s %s%s\n' \
			"${ports[$i]}" "${versions[$i]}" "${branches[$i]}" "${dirs[$i]}" \
			"$([ "${currents[$i]}" = yes ] && echo '  <- this checkout')"
	done
}

case "$MODE" in
env)
	# One server: use it, wherever it runs from. Several: prefer this checkout's own.
	pick=0
	if [ "${#ports[@]}" -gt 1 ]; then
		pick=-1
		matches=0
		for i in "${!ports[@]}"; do
			if [ "${currents[$i]}" = yes ]; then
				pick=$i
				matches=$((matches + 1))
			fi
		done
		if [ "$matches" -ne 1 ]; then
			echo "SERVER_FOUND=0"
			{
				echo "find-server.sh: ${#ports[@]} dev servers are running and none is clearly the one to use."
				echo 'Pass --port to say which:'
				print_table | sed 's/^/  /'
			} >&2
			exit 1
		fi
	fi
	echo "SERVER_FOUND=1"
	echo "SERVER_PORT=${ports[$pick]}"
	echo "SERVER_BASE_URL=http://localhost:${ports[$pick]}"
	echo "SERVER_MONGO_URL=${mongos[$pick]}"
	echo "SERVER_DIR=${dirs[$pick]}"
	echo "SERVER_BRANCH=${branches[$pick]}"
	echo "SERVER_VERSION=${versions[$pick]}"
	;;
json)
	for i in "${!ports[@]}"; do
		printf '{"port":%s,"mongoUrl":"%s","dir":"%s","branch":"%s","version":"%s","currentCheckout":%s}\n' \
			"${ports[$i]}" "${mongos[$i]}" "${dirs[$i]}" "${branches[$i]}" "${versions[$i]}" \
			"$([ "${currents[$i]}" = yes ] && echo true || echo false)"
	done
	;;
table)
	print_table
	;;
esac
