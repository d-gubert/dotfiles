#!/usr/bin/env bash
#
# Runs on the HOST from `devbox template` and, on a first run, from `devbox up`.
#
# Builds ../Dockerfile into the sandbox *template* — the image an sbx sandbox VM
# boots from — and loads it into the sandbox runtime's own image store:
#
#     docker build   ->  sbx template save --output       ->  sbx template load
#     (host engine)      (a tar in the state directory)       (the sbx runtime)
#
# Two image stores are involved because they are two runtimes. The host Docker
# Engine is what has a builder; the sbx runtime has its own containerd inside the
# VM and can only be handed a tar. `sbx template load` is that hand-off, and it
# is why nothing here needs a registry, a login or a push.
#
# The build itself is ordinary `docker build`, so BuildKit's layer cache applies
# and a rebuild after an edit to one RUN line costs that line onwards.
#
# Usage: build-template.sh [--no-cache]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home="$(cd "$here/.." && pwd)"

tag="${DEVBOX_TEMPLATE:?}"
state="${DEVBOX_STATE:?}"
tar="$state/template.tar"

log() { printf '\033[1;34m[template]\033[0m %s\n' "$1"; }
die() {
	printf '\033[1;31m[template] ERROR:\033[0m %s\n' "$1" >&2
	exit 1
}

build=(docker build --tag "$tag" --file "$home/Dockerfile")
[ "${1:-}" = "--no-cache" ] && build+=(--no-cache)
build+=("$home")

log "building $tag from $home/Dockerfile"
"${build[@]}" || die "docker build failed"

# --output writes the tar; the snapshot half of `sbx template save` is not what
# is wanted here, so the export goes through the host engine instead.
mkdir -p "$state"
log "exporting $tag"
docker save "$tag" --output "$tar" || die "docker save failed"

log "loading $tag into the sandbox runtime"
sbx template load "$tar" || die "sbx template load failed"

# The tar is a full copy of the image and is worth nothing once loaded.
rm -f "$tar"

log "$tag is ready — \`devbox rebuild\` recreates existing sandboxes on it"
