#!/usr/bin/env bash
#
# Call the REST API of the running dev server, as the e2e admin.
#
# It discovers the port, logs in, and caches the token, so a setup or a cleanup call is one line.
# Use it for the checks around a recording: which apps are installed, what the room holds, what a
# setting is set to.
#
# Usage:
#   rc-api.sh GET  /api/v1/settings.public
#   rc-api.sh GET  /api/apps/installed
#   rc-api.sh POST /api/v1/users.setStatus '{"status":"online","username":"user1"}'
#   rc-api.sh POST /api/v1/rooms.cleanHistory '{"roomId":"<id>","latest":"2100-01-01T00:00:00.000Z","oldest":"2000-01-01T00:00:00.000Z"}'
#
# Options:
#   --port N     override the discovered port
#   --raw        print the body with no jq formatting
#
# Note the two API prefixes: the core API is under /api/v1, the Apps-Engine API is under /api.
#
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# From apps/meteor/tests/e2e/config/constants.ts. TEST_MODE=api seeds this account.
ADMIN_USER='rocketchat.internal.admin.test'
ADMIN_PASS='rocketchat.internal.admin.test'

PORT=''
RAW=0
ARGS=()
while [ $# -gt 0 ]; do
	case "$1" in
	--port)
		PORT=$2
		shift 2
		;;
	--raw)
		RAW=1
		shift
		;;
	-h | --help)
		sed -n '2,22p' "$0"
		exit 0
		;;
	*)
		ARGS+=("$1")
		shift
		;;
	esac
done

METHOD=${ARGS[0]:-}
PATH_ARG=${ARGS[1]:-}
BODY=${ARGS[2]:-}

if [ -z "$METHOD" ] || [ -z "$PATH_ARG" ]; then
	echo 'rc-api.sh: pass a method and a path, e.g. `rc-api.sh GET /api/v1/me`.' >&2
	exit 2
fi

if [ -z "$PORT" ]; then
	if server_env=$("$SCRIPT_DIR/find-server.sh" --env); then
		eval "$server_env"
		PORT=$SERVER_PORT
	else
		echo 'rc-api.sh: no dev server to call. Run preflight.sh for the detail.' >&2
		exit 1
	fi
fi

BASE="http://localhost:$PORT"
CACHE="${TMPDIR:-/tmp}/rc-api-token-$PORT"

login() {
	local response
	response=$(curl -s -m 15 -X POST "$BASE/api/v1/login" \
		-H 'Content-Type: application/json' \
		-d "{\"user\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")
	local token user_id
	token=$(printf '%s' "$response" | sed -n 's/.*"authToken":"\([^"]*\)".*/\1/p')
	user_id=$(printf '%s' "$response" | sed -n 's/.*"userId":"\([^"]*\)".*/\1/p')
	if [ -z "$token" ] || [ -z "$user_id" ]; then
		echo 'rc-api.sh: the admin login failed. Is the server started with TEST_MODE=api?' >&2
		printf '%s\n' "$response" >&2
		return 1
	fi
	# Note: do not name a shell variable UID; zsh makes it read-only.
	printf 'RC_TOKEN=%s\nRC_USER_ID=%s\n' "$token" "$user_id" >"$CACHE"
	chmod 600 "$CACHE"
}

call() {
	local args=(-s -m 30 -X "$METHOD" "$BASE$PATH_ARG"
		-H "X-Auth-Token: $RC_TOKEN" -H "X-User-Id: $RC_USER_ID")
	if [ -n "$BODY" ]; then
		args+=(-H 'Content-Type: application/json' -d "$BODY")
	fi
	curl "${args[@]}"
}

[ -f "$CACHE" ] || login || exit 1
# shellcheck disable=SC1090
. "$CACHE"

RESPONSE=$(call)
# A cached token expires when the server restarts; log in again once and retry.
case "$RESPONSE" in
*'"status":"error"'* | *'unauthorized'* | *'"message":"You must be logged in to do this."'*)
	login || exit 1
	# shellcheck disable=SC1090
	. "$CACHE"
	RESPONSE=$(call)
	;;
esac

if [ "$RAW" -eq 0 ] && command -v jq >/dev/null; then
	printf '%s' "$RESPONSE" | jq . 2>/dev/null || printf '%s\n' "$RESPONSE"
else
	printf '%s\n' "$RESPONSE"
fi
