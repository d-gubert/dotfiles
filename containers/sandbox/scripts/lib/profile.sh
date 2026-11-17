#!/usr/bin/env bash
#
# Sourced, not executed. Decides which projects/<name>/ profile a workspace gets.
#
# A profile is how a repository's own setup reaches a deliberately generic
# sandbox: its dependency install, the extra hosts its toolchain needs, the ports
# it serves on, the environment it expects. Everything in a profile is optional,
# and a workspace that matches nothing gets `default`, which is the bare
# toolchain image.
#
#   projects/<name>/
#     match              host path globs, one per line — what picks this profile
#     env                KEY=VALUE lines, added to the sandbox's environment
#     env.local          the same, gitignored, for anything secret
#     ports              host:container per line, published to the host
#     volumes            `path [size]` per line, block storage inside the sandbox
#     allowed-domains    extra egress allowlist entries
#     setup.sh           runs in the sandbox once, at create
#     initialize.sh      runs on the host once, before create
#
# Matching is by glob against the workspace's absolute host path, first match
# wins, profiles visited in alphabetical order. `default` never matches by path —
# it is only the fallback. Override the whole thing with `devbox --profile <name>`
# or DEVBOX_PROFILE.

_profile_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_profile_root="$(cd "$_profile_lib_dir/../.." && pwd)/projects"

# profile_dir <name> — absolute path of a profile directory (whether or not it
# exists, so callers can just test the files they care about).
profile_dir() {
	printf '%s\n' "$_profile_root/$1"
}

# profile_resolve <workspace-path> — prints the profile name for a workspace.
#
# Case patterns are deliberately unquoted: the file holds globs, and matching
# them literally would make the file useless. A leading `~/` is expanded, since
# the paths worth matching almost all start there and nothing else in the file is
# shell-evaluated.
profile_resolve() {
	local ws="$1" dir name pattern
	for dir in "$_profile_root"/*/; do
		dir="${dir%/}"
		name="$(basename "$dir")"
		[ "$name" = "default" ] && continue
		[ -f "$dir/match" ] || continue
		# `|| [ -n "$pattern" ]` so a last line without a trailing newline counts.
		while IFS= read -r pattern || [ -n "$pattern" ]; do
			pattern="${pattern%%#*}"
			# Trim surrounding whitespace only — a glob may legitimately contain
			# spaces in the middle.
			pattern="${pattern#"${pattern%%[![:space:]]*}"}"
			pattern="${pattern%"${pattern##*[![:space:]]}"}"
			[ -n "$pattern" ] || continue
			[ "${pattern#\~/}" != "$pattern" ] && pattern="$HOME/${pattern#\~/}"
			# shellcheck disable=SC2254
			case "$ws" in
			$pattern)
				printf '%s\n' "$name"
				return 0
				;;
			esac
		done <"$dir/match"
	done
	printf 'default\n'
}
