#!/bin/sh
#
# Environment for a shell inside a Docker Sandboxes sandbox (`sbx`).
#
# A sandbox is a VM with its own home directory, its own loopback and a
# default-deny egress interceptor in front of it. Nothing on the host is visible
# from in here, so everything that differs from a host shell is collected in this
# one file rather than spread through .zshrc as `if [[ -n $IS_SANDBOX ]]` arms.
#
# Sourced from two places, because two different launch paths need the same
# variables:
#
#   common/.zshrc              an interactive shell — `sbx exec <name> zsh`.
#   /etc/sandbox-persistent.sh the `claude` that sbx starts itself. That one is
#                              not a login shell and reads no rc file; sbx points
#                              BASH_ENV and CLAUDE_ENV_FILE at that path, so a
#                              one-line `.` of this file covers it.
#
# POSIX sh and not zsh, for the second reader: BASH_ENV makes bash read it.
#
# It is sourced, never executed, so `return` is what ends it early.

# Set by sbx itself. A host shell that sources this file by accident does
# nothing, which is what makes the guard in .zshrc a convenience and not the
# thing correctness rests on.
[ -n "$IS_SANDBOX" ] || return 0

# BASH_ENV fires on every non-interactive bash, so this file is read again for
# every script the agent runs. The work below is a handful of exports and one
# `awk`; the guard is exported, so the second read of a process tree stops here.
[ -n "$DOTFILES_SANDBOX_ENV" ] && return 0
export DOTFILES_SANDBOX_ENV=1

# --- Which workspace this is --------------------------------------------------
#
# sbx bind-mounts the host workspace over virtiofs, at the same path it has on
# the host, and names the source `host`. That mount is the only thing in here
# that says WHICH checkout the sandbox was created for — the sandbox name is
# close (sbx defaults it to <agent>-<workdir>) but `--name` can make it
# anything, and the agent prefix would have to be guessed off the front.
#
# The basename, not the path: the path is the host's, and every worktree of a
# repo would otherwise be a full-length label in the dashboard.
sandbox_workspace=$(awk '$1 == "host" && $3 == "virtiofs" { print $2; exit }' /proc/mounts 2>/dev/null)
sandbox_workspace=${sandbox_workspace##*/}
# The sandbox name is the fallback, not the first choice, for the reason above.
[ -n "$sandbox_workspace" ] || sandbox_workspace="$SANDBOX_NAME"

# --- Claude Code telemetry -> the observability stack on the HOST -------------
#
# The same variables common/.zshrc exports on the host, and containers/
# devcontainer/scripts/claude-code/initialize.sh sets in a devbox container. Read
# either one for what each of them does and why; only the two that differ are
# commented here.
#
# No reachability probe, unlike the host block in .zshrc. sbx's interceptor
# accepts every outbound connection before it checks policy or dials anything,
# so a probe from in here reports success whether the collector is up or not.
# There is nothing cheap to test, so this exports unconditionally.
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_LOG_TOOL_DETAILS=1
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
# host.docker.internal, which is how a sandbox reaches a service on the host.
# 127.0.0.1 in here is the sandbox's own loopback and holds nothing:
# https://docs.docker.com/ai/sandboxes/workflows/development/#accessing-host-services-from-a-sandbox
#
# The collector needs no extra binding for this. sbx's proxy rewrites the name to
# `localhost` and dials from the host, so the loopback publish in
# containers/observability/docker-compose.yml is what answers.
#
# That rewrite is also why the policy rule names a host this file never sends to.
# The allowlist is matched AFTER the translation:
#
#   sbx policy allow network --sandbox <name> localhost:4317
#
# An allow rule for host.docker.internal:4317 looks right and never matches.
# Without a matching rule the export fails silently — the interceptor accepts the
# connection and then drops it.
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
export OTEL_METRIC_EXPORT_INTERVAL=10000
# `sbx:` is the third origin, beside `host:` from .zshrc and the container
# workspace path from a devbox. A sandbox is neither of those and must not be
# totalled into either.
#
# Fixed for the life of the sandbox, so no wrapper narrows it per invocation the
# way the host's `claude()` does: a sandbox holds exactly one workspace, and this
# is it.
export OTEL_RESOURCE_ATTRIBUTES="workspace=sbx:${sandbox_workspace}"

unset sandbox_workspace
