#!/usr/bin/env bash
#
# add-devcontainer.sh — drop the Claude Code sandbox devcontainer template into
# a project. Run it from the project root (or pass a target dir).
#
# Usage:
#   add-devcontainer.sh [target-dir]   # default: current directory
#   add-devcontainer.sh --force        # overwrite an existing .devcontainer
#   add-devcontainer.sh --worktree     # git-worktree-aware variant (see below)
#
# --worktree:
#   Generates a devcontainer that works from inside a linked git worktree.
#   A worktree's .git is a file pointing at an ABSOLUTE host path under the main
#   checkout's .git, so the default single-folder mount breaks git. This mode
#   bind-mounts the worktree AND the main checkout at their IDENTICAL host paths
#   so those absolute pointers resolve, and shares one Claude auth volume across
#   all worktrees. Run it from within the worktree you want to open.
#
set -euo pipefail

FORCE=0
WORKTREE=0
TARGET="$PWD"
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    -w|--worktree) WORKTREE=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TARGET="$arg" ;;
  esac
done

# Template lives alongside this script: <repo>/scripts/ -> <repo>/templates/...
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/devcontainer"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "[add-devcontainer] template not found at $TEMPLATE_DIR" >&2
  exit 1
fi

# ── Worktree mode: resolve the identical-path mounts before choosing DEST ────
if [ "$WORKTREE" -eq 1 ]; then
  if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[add-devcontainer] --worktree must be run inside a git work tree" >&2
    exit 1
  fi
  WT_TOP="$(git -C "$TARGET" rev-parse --show-toplevel)"
  COMMON_DIR="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -z "$COMMON_DIR" ]; then
    COMMON_DIR="$(cd "$TARGET" && cd "$(git rev-parse --git-common-dir)" && pwd)"
  fi
  MAIN_CHECKOUT="$(dirname "$COMMON_DIR")"   # strip the trailing /.git
  # Put .devcontainer at the worktree root regardless of where we were invoked.
  TARGET="$WT_TOP"
fi

DEST="$TARGET/.devcontainer"
if [ -d "$DEST" ] && [ "$FORCE" -ne 1 ]; then
  echo "[add-devcontainer] $DEST already exists. Re-run with --force to overwrite." >&2
  exit 1
fi

mkdir -p "$DEST"
cp "$TEMPLATE_DIR/Dockerfile" "$TEMPLATE_DIR/init-firewall.sh" "$DEST/"
chmod +x "$DEST/init-firewall.sh"

if [ "$WORKTREE" -eq 0 ]; then
  cp "$TEMPLATE_DIR/devcontainer.json" "$DEST/"
  echo "[add-devcontainer] wrote sandbox devcontainer to $DEST"
  echo "[add-devcontainer] next: \"Reopen in Container\" in VS Code, or"
  echo "[add-devcontainer]       devcontainer up --workspace-folder \"$TARGET\""
  exit 0
fi

# ── Generate the worktree-aware devcontainer.json ───────────────────────────
# Mount the worktree at its own path; if the main checkout is a separate dir
# (siblings, the common layout) mount it too. If the worktree lives *inside* the
# main checkout, one mount of the main checkout already covers it.
EXTRA_MOUNT=""
case "$WT_TOP/" in
  "$MAIN_CHECKOUT"/*)
    WS_MOUNT_SRC="$MAIN_CHECKOUT"   # worktree nested in main; single mount
    ;;
  *)
    WS_MOUNT_SRC="$WT_TOP"
    # Real newline (not \n) — this is interpolated into the heredoc verbatim.
    EXTRA_MOUNT=",
    \"source=${MAIN_CHECKOUT},target=${MAIN_CHECKOUT},type=bind\""
    ;;
esac

cat > "$DEST/devcontainer.json" <<EOF
{
  "name": "Claude Code Sandbox (worktree)",
  "build": {
    "dockerfile": "Dockerfile",
    "args": { "TZ": "\${localEnv:TZ:America/Sao_Paulo}" }
  },
  "runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"],
  "customizations": {
    "vscode": {
      "extensions": ["eamodio.gitlens", "anthropic.claude-code"],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh",
        "terminal.integrated.profiles.linux": { "zsh": { "path": "zsh" } }
      }
    }
  },
  "remoteUser": "node",
  "remoteEnv": {
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude",
    "POWERLEVEL9K_DISABLE_GITSTATUS": "true",
    "GITHUB_TOKEN": "\${localEnv:GITHUB_TOKEN}",
    "ANTHROPIC_API_KEY": "\${localEnv:ANTHROPIC_API_KEY}"
  },
  // Bind the worktree AND the main checkout at their real host paths so the
  // worktree's absolute .git pointer resolves. Auth volume is shared (fixed
  // name) so you log in to Claude once across all worktrees; history stays
  // per-worktree via devcontainerId.
  "workspaceMount": "source=${WS_MOUNT_SRC},target=${WS_MOUNT_SRC},type=bind,consistency=delegated",
  "workspaceFolder": "${WT_TOP}",
  "mounts": [
    "source=claude-code-bashhistory-\${devcontainerId},target=/commandhistory,type=volume",
    "source=claude-code-config-shared,target=/home/node/.claude,type=volume"${EXTRA_MOUNT}
  ],
  "postCreateCommand": "sudo /usr/local/bin/init-firewall.sh"
}
EOF

echo "[add-devcontainer] wrote WORKTREE devcontainer to $DEST"
echo "[add-devcontainer]   worktree      : $WT_TOP"
echo "[add-devcontainer]   main checkout : $MAIN_CHECKOUT"
if [ -n "$EXTRA_MOUNT" ]; then
  echo "[add-devcontainer]   mounts        : both, at identical host paths"
else
  echo "[add-devcontainer]   mounts        : single (worktree nested in main checkout)"
fi
echo "[add-devcontainer] next: devcontainer up --workspace-folder \"$WT_TOP\""
echo "[add-devcontainer]       then: devcontainer exec --workspace-folder \"$WT_TOP\" zsh"
