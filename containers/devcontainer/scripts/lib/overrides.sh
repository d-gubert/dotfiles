#!/usr/bin/env bash
#
# Sourced, not executed. Builds docker-compose.overrides.yml — the one generated
# compose file devcontainer.json includes alongside docker-compose.yml.
#
# Why anything is generated: compose files are static and devcontainer.json's
# `dockerComposeFile` list cannot be computed, yet almost everything that makes a
# container *this* container is only knowable on the host at initializeCommand
# time — whether the checkout is a linked git worktree, which profile the
# workspace matched, and which features devcontainer.json declares. Everything a
# feature or a profile owns (its shared volume, where that volume mounts, its
# environment, any capability it needs) therefore has to be injected rather than
# checked in, or commenting a feature out would still leave compose demanding its
# external volume and failing the create outright.
#
# It is written to the *per-workspace* state directory, not into this shared
# dotfiles directory: several workspaces can be brought up at once, and each
# needs its own mounts, ports and environment. $DEVBOX_OVERRIDES_OUT is set by
# scripts/initialize.sh from $DEVBOX_STATE, which is the same path
# devcontainer.json's `dockerComposeFile` points at.
#
# Contributors never write the file. Each appends a fragment to a staging
# directory under one of four buckets, and initialize.sh merges them once at the
# end:
#
#   service              arbitrary keys under services.app (cap_add, ports, ...)
#   service-environment  KEY: "value" lines for services.app.environment
#   service-volumes      list items for services.app.volumes
#   volumes              entries for the top-level volumes map
#   networks             entries for the top-level networks map
#
# Buckets exist because YAML has no merge: two fragments both opening `volumes:`
# under the same node would be a duplicate key, which compose rejects. Within a
# bucket, merging is concatenation at a fixed indent — so a fragment is authored
# unindented and reads fine on its own. `environment` has a bucket of its own for
# exactly that reason: the git identity and the profile both want to add
# variables, and neither can open the key.
#
# The staging directory is passed to child scripts through the environment
# (DEVBOX_COMPOSE_OVERRIDES_DIR) because they run as separate `bash` processes,
# not as sourced functions.

# Buckets in emit order. `service` first only so the generated file reads with
# the environment and volume lists last, like a hand-written one.
#
# A fragment in `networks` declares a network the container attaches to but does
# not own — always `external`, because whatever creates it (the turbo cache, the
# local mongo stack) has to outlive any one workspace. Attaching to it is a
# separate `service` fragment: compose merges the service's `networks` with the
# base file's list rather than replacing it, so a fragment names only what it
# adds.
_overrides_buckets=(service service-environment service-volumes volumes networks)

_overrides_out() {
	if [ -z "${DEVBOX_OVERRIDES_OUT:-}" ]; then
		printf '\033[1;31m[overrides]\033[0m DEVBOX_OVERRIDES_OUT is unset — this runs from scripts/initialize.sh\n' >&2
		return 1
	fi
	printf '%s\n' "$DEVBOX_OVERRIDES_OUT"
}

_overrides_dir() {
	if [ -z "${DEVBOX_COMPOSE_OVERRIDES_DIR:-}" ]; then
		printf '\033[1;31m[overrides]\033[0m DEVBOX_COMPOSE_OVERRIDES_DIR is unset — this runs from scripts/initialize.sh\n' >&2
		return 1
	fi
	printf '%s\n' "$DEVBOX_COMPOSE_OVERRIDES_DIR"
}

# overrides_reset — creates the staging directory and exports its path.
# Called once, by initialize.sh, before any contributor runs.
overrides_reset() {
	DEVBOX_COMPOSE_OVERRIDES_DIR="$(mktemp -d)"
	export DEVBOX_COMPOSE_OVERRIDES_DIR
}

# overrides_cleanup — removes the staging directory. Safe to call twice.
overrides_cleanup() {
	[ -n "${DEVBOX_COMPOSE_OVERRIDES_DIR:-}" ] || return 0
	rm -rf "$DEVBOX_COMPOSE_OVERRIDES_DIR"
}

# overrides_add <contributor> <bucket> — fragment body on stdin.
#
# One file per contributor per bucket, so a contributor that runs twice (the
# hooks are all idempotent) replaces its own fragment instead of duplicating it.
overrides_add() {
	local contributor="$1" bucket="$2" dir known found=
	dir="$(_overrides_dir)" || return 1
	for known in "${_overrides_buckets[@]}"; do
		[ "$bucket" = "$known" ] && found=1
	done
	if [ -z "$found" ]; then
		printf '\033[1;31m[overrides]\033[0m unknown bucket "%s"\n' "$bucket" >&2
		return 1
	fi
	mkdir -p "$dir/$bucket"
	cat >"$dir/$bucket/$contributor.yml"
}

# overrides_yaml_escape <value> — escapes a value for a YAML double-quoted
# scalar that compose then interpolates:
#   \ and "  are YAML escapes
#   $        is compose interpolation — a literal one has to be doubled, or a
#            value like "Foo $USER Bar" is silently rewritten
overrides_yaml_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/$$/g'
}

# True when any contributor wrote to <bucket>.
_overrides_has() {
	local dir
	dir="$(_overrides_dir)" || return 1
	[ -n "$(ls -A "$dir/$1" 2>/dev/null)" ]
}

# Emits every fragment in <bucket>, each prefixed with a comment naming its
# contributor and indented by <pad> spaces. Blank lines stay blank rather than
# collecting trailing whitespace.
_overrides_emit() {
	local bucket="$1" pad="$2" dir file
	dir="$(_overrides_dir)" || return 1
	for file in "$dir/$bucket"/*.yml; do
		[ -f "$file" ] || continue
		awk -v pad="$pad" -v src="$(basename "${file%.yml}")" '
			BEGIN { for (i = 0; i < pad; i++) indent = indent " "; print indent "# " src }
			{ print (length($0) ? indent $0 : "") }
		' "$file"
	done
}

# overrides_write — merges the staged fragments into $DEVBOX_OVERRIDES_OUT.
overrides_write() {
	local out
	out="$(_overrides_out)" || return 1
	_overrides_dir >/dev/null || return 1
	mkdir -p "$(dirname "$out")"
	{
		echo "# Generated by \$DEVBOX_HOME/scripts/initialize.sh — do not edit."
		echo "#"
		echo "# Rewritten on every container create; anything changed here is lost. What"
		echo "# lands in this file depends on the workspace (its profile, whether it is a"
		echo "# linked git worktree) and on which features devcontainer.json declares —"
		echo "# see scripts/lib/overrides.sh."
		echo "services:"
		if _overrides_has service || _overrides_has service-environment || _overrides_has service-volumes; then
			echo "  app:"
			_overrides_emit service 4
			if _overrides_has service-environment; then
				echo "    environment:"
				_overrides_emit service-environment 6
			fi
			if _overrides_has service-volumes; then
				echo "    volumes:"
				_overrides_emit service-volumes 6
			fi
		else
			# devcontainer.json includes this file unconditionally, so it has to be
			# valid compose even when nothing contributed to it.
			echo "  app: {}"
		fi
		if _overrides_has volumes; then
			echo "volumes:"
			_overrides_emit volumes 2
		fi
		if _overrides_has networks; then
			echo "networks:"
			_overrides_emit networks 2
		fi
	} >"$out"
}
