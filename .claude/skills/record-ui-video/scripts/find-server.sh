#!/usr/bin/env bash
#
# Find the running Rocket.Chat dev servers and report the facts a recording needs:
# the port, the Mongo connection string, the worktree that serves it, and the version.
#
# Why this exists: a machine often runs several worktrees at once. A recording driven against
# the wrong worktree records the wrong code, and `ss -ltnp` alone does not say which worktree a
# port belongs to. This reads each candidate process's own environment instead of guessing.
#
# Usage:
#   find-server.sh            # human table of every server found
#   find-server.sh --env      # shell assignments for the server of THIS worktree; exit 1 if none
#   find-server.sh --json     # one JSON object per server
#
set -uo pipefail

MODE=table
case "${1:-}" in
	--env) MODE=env ;;
	--json) MODE=json ;;
	--table | '') MODE=table ;;
	-h | --help)
		sed -n '2,20p' "$0"
		exit 0
		;;
	*)
		echo "find-server.sh: unknown argument '$1'" >&2
		exit 2
		;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '')

# Collect candidates as "port|mongo_url|meteor_pwd|pid", deduplicated. Meteor runs several
# processes that share one environment, so the same server appears many times.
#
# Take the port from ROOT_URL, not from PORT. In dev, meteor puts a proxy on the port you asked
# for and runs the inner app server on a port of its own choosing, and the inner process carries
# that private port in PORT. ROOT_URL holds the port a browser must use, in every process.
candidates=$(
	for proc in /proc/[0-9]*; do
		pid=${proc#/proc/}
		env_data=$( (tr '\0' '\n' <"$proc/environ") 2>/dev/null ) || continue
		[ -n "$env_data" ] || continue
		case "$env_data" in
		*ROOT_URL=*) ;;
		*) continue ;;
		esac
		app_pwd=$(printf '%s\n' "$env_data" | sed -n 's/^PWD=//p' | head -1)
		case "$app_pwd" in
		*/apps/meteor) ;;
		*) continue ;;
		esac
		root_url=$(printf '%s\n' "$env_data" | sed -n 's/^ROOT_URL=//p' | head -1)
		port=$(printf '%s\n' "$root_url" | sed -n 's|^https\{0,1\}://[^:/]*:\([0-9]\{1,\}\).*|\1|p')
		# ROOT_URL without an explicit port: fall back to PORT.
		[ -n "$port" ] || port=$(printf '%s\n' "$env_data" | sed -n 's/^PORT=//p' | head -1)
		mongo=$(printf '%s\n' "$env_data" | sed -n 's/^MONGO_URL=//p' | head -1)
		[ -n "$port" ] || continue
		printf '%s|%s|%s|%s\n' "$port" "$mongo" "$app_pwd" "$pid"
	done | sort -t'|' -k1,3 -u | awk -F'|' '!seen[$1"|"$3]++'
)

if [ -z "$candidates" ]; then
	case "$MODE" in
	env) echo "SERVER_FOUND=0" ;;
	json) echo '[]' ;;
	table) echo "No Rocket.Chat dev server is running." ;;
	esac
	exit 1
fi

# Ask each server for its own version. A process can be mid-build and not answer yet.
probe_version() {
	curl -s -m 5 "http://localhost:$1/api/info" 2>/dev/null |
		sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1
}

emit_env=0
rows=''
while IFS='|' read -r port mongo app_pwd pid; do
	[ -n "$port" ] || continue
	worktree=${app_pwd%/apps/meteor}
	version=$(probe_version "$port")
	[ -n "$version" ] || version='(not answering yet)'
	mine=no
	if [ -n "$REPO_ROOT" ] && [ "$worktree" = "$REPO_ROOT" ]; then
		mine=yes
	fi
	branch=$(git -C "$worktree" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')

	case "$MODE" in
	env)
		if [ "$mine" = yes ] && [ "$emit_env" -eq 0 ]; then
			emit_env=1
			echo "SERVER_FOUND=1"
			echo "SERVER_PORT=$port"
			echo "SERVER_BASE_URL=http://localhost:$port"
			echo "SERVER_MONGO_URL=$mongo"
			echo "SERVER_WORKTREE=$worktree"
			echo "SERVER_BRANCH=$branch"
			echo "SERVER_VERSION=$version"
		fi
		;;
	json)
		printf '{"port":%s,"mongoUrl":"%s","worktree":"%s","branch":"%s","version":"%s","thisWorktree":%s,"pid":%s}\n' \
			"$port" "$mongo" "$worktree" "$branch" "$version" "$([ "$mine" = yes ] && echo true || echo false)" "$pid"
		;;
	table)
		rows="$rows$port|$version|$branch|$worktree|$mine"$'\n'
		;;
	esac
done <<<"$candidates"

case "$MODE" in
env)
	if [ "$emit_env" -eq 0 ]; then
		echo "SERVER_FOUND=0"
		echo "# A server is running, but not from this worktree ($REPO_ROOT)." >&2
		echo "# Run find-server.sh with no argument to see which worktrees are served." >&2
		exit 1
	fi
	;;
table)
	printf 'PORT  VERSION  BRANCH                          WORKTREE (this worktree?)\n'
	printf '%s' "$rows" | while IFS='|' read -r port version branch worktree mine; do
		[ -n "$port" ] || continue
		printf '%-5s %-8s %-31s %s (%s)\n' "$port" "$version" "$branch" "$worktree" "$mine"
	done
	;;
esac
