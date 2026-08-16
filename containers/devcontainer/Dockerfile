FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-24.04

# A workspace-agnostic image: the JS toolchain plus what the egress firewall
# needs, and nothing that belongs to any single repository.
#
# Per-project toolchains do NOT go here. They belong to a profile
# (projects/<name>/setup.sh), which installs them into $DEVBOX_TOOLS — a volume
# shared by every workspace on that profile, so a rebuild of this image does not
# re-download them. Adding a repo's pins here would defeat the point of one image
# serving every checkout on the machine.

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    jq \
    libssl-dev \
    ripgrep \
    unzip \
    # Tooling for the default-deny egress firewall (scripts/claude-code/init-firewall.sh)
    iptables \
    ipset \
    dnsutils \
    aggregate && \
    rm -rf /var/lib/apt/lists/*

# --- Node via Volta -----------------------------------------------------------
# Volta manages the Node/Yarn/pnpm toolchain and transparently honours the
# `volta` and `packageManager` fields in a project's package.json — which is what
# makes one image usable across repos that pin different versions. The versions
# baked in below are only the fallback for a project that pins nothing.
#
# Installed into /usr/local rather than a home directory so the toolchain
# survives the home directory being whatever the remote user's is, and so a
# project-pinned version fetched at runtime is visible to every shell.
ARG NODE_VERSION=22.22.3
ARG YARN_VERSION=4.17.1
ARG PNPM_VERSION=11.15.0
ENV VOLTA_HOME="/usr/local/volta"
ENV PATH="$VOLTA_HOME/bin:$PATH"
# pnpm support is still behind a flag in Volta 2.x, and it has to be set for both
# `volta install` and every later shim invocation — hence ENV, not a build arg.
ENV VOLTA_FEATURE_PNPM=1
RUN mkdir -p $VOLTA_HOME && \
    curl https://get.volta.sh | bash -s -- --skip-setup && \
    volta install node@$NODE_VERSION && \
    volta install yarn@$YARN_VERSION && \
    volta install pnpm@$PNPM_VERSION && \
    # Volta fetches project-pinned toolchains at runtime, as `vscode`, into this
    # same directory — so it has to be writable by that user, not just root.
    chown -R vscode:vscode "$VOLTA_HOME" && \
    printf 'export VOLTA_HOME="/usr/local/volta"\nexport VOLTA_FEATURE_PNPM=1\nexport PATH="$VOLTA_HOME/bin:$PATH"\n' \
      >/etc/profile.d/volta.sh

# --- Neovim -------------------------------------------------------------------
# The editor for anything that opens one inside the container — `git commit`,
# `git rebase -i`, a Claude Code prompt for an edit. It belongs here rather than
# in a profile for the same reason Volta does: it reads any repository and pins
# nothing.
#
# From the upstream tarball rather than apt: Ubuntu 24.04 ships 0.9.5, which is
# past end of life and below the >= 0.11 floor that the nvim config in these
# dotfiles (common/.config/nvim) needs. Nothing mounts that config into the
# container today, but an old build would make it impossible later.
#
# Unpacked whole into /usr/local/nvim, with one symlink onto the default PATH,
# so no profile.d file is needed and `rm -rf` removes every trace.
ARG NVIM_VERSION=0.12.4
RUN case "$(dpkg --print-architecture)" in \
      amd64) nvim_arch=x86_64 ;; \
      arm64) nvim_arch=arm64 ;; \
      *) echo "unsupported architecture for neovim" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/nvim.tar.gz \
      "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${nvim_arch}.tar.gz" && \
    mkdir -p /usr/local/nvim && \
    tar -xzf /tmp/nvim.tar.gz -C /usr/local/nvim --strip-components=1 && \
    rm /tmp/nvim.tar.gz && \
    ln -s /usr/local/nvim/bin/nvim /usr/local/bin/nvim && \
    nvim --version

# An image-level ENV, not a `containerEnv` entry in devcontainer.json, so that a
# plain `docker exec` into this container gets it too — not only the shells the
# devcontainer CLI starts.
ENV EDITOR=nvim

# --- GitNexus ----------------------------------------------------------------
# Indexes a checkout into a code knowledge graph and serves it to Claude Code
# over MCP. It belongs here rather than in a profile for the same reason Volta
# does: it reads any repository and pins nothing, so one install serves every
# checkout. https://github.com/abhigyanpatwari/GitNexus
#
# Baked into the image rather than installed by a lifecycle hook because the
# install is ~250 packages and its postinstall activates native tree-sitter
# bindings — work that should happen once per rebuild, not once per container.
# It also needs the npm registry, which the egress firewall allows but which a
# create-time install would make a hard dependency of every `devbox up`.
#
# Node >= 22 is a hard engine requirement, which the Volta default above meets.
# The vendored grammars ship prebuilds for linux-x64/arm64, so nothing is
# compiled here and no extra build tooling is needed (build-essential is
# installed above regardless).
ARG GITNEXUS_VERSION=1.6.9
RUN npm install -g "gitnexus@$GITNEXUS_VERSION" && \
    # npm ran as root and wrote into $VOLTA_HOME (the shim plus the package
    # itself), so repeat the claim the Volta block makes above — otherwise
    # `vscode` cannot install a project-pinned toolchain afterwards.
    chown -R vscode:vscode "$VOLTA_HOME"

# GitNexus's index is a LadybugDB database, and full-text/BM25 search needs that
# engine's FTS extension — a separate download from extension.ladybugdb.com,
# which `analyze` attempts on its own (its install policy defaults to `auto`).
# Behind the egress firewall that attempt fails, and analyze then degrades to an
# index with no text search, warning but succeeding — a failure mode that is easy
# to miss.
#
# So fetch it here instead, where there is no firewall, and keep the host off the
# allowlist entirely. The extension is cached under $HOME/.lbdb, so this MUST run
# as `vscode`: a copy under /root is invisible to the user that later runs the
# tool. `--verify-only` is the package's own build-time gate for exactly that
# mistake — it re-resolves the extension in a fresh process under this HOME and
# fails the build on a mismatch, instead of leaving search quietly broken.
#
# The positional argument is LBUG_MAX_DB_SIZE (16 GiB, the package default); the
# installer only uses it to open a throwaway scratch database.
#
# The installer is located by search rather than with `npm root -g`, which under
# Volta answers the *Node image's* node_modules — not where a `volta install`d
# package actually lands ($VOLTA_HOME/tools/image/packages/<pkg>/lib/...).
USER vscode
RUN installer="$(find "$VOLTA_HOME/tools/image/packages/gitnexus" \
      -name install-duckdb-extension.mjs -print -quit)" && \
    [ -n "$installer" ] && \
    node "$installer" fts 17179869184 && \
    node "$installer" fts 17179869184 --verify-only
USER root

# Neither the lifecycle scripts nor the egress firewall are copied into the
# image: this whole directory is bind-mounted read-only at /opt/devbox, so
# postStartCommand runs them straight from there and edits take effect on a
# restart, no rebuild. The firewall's tooling is installed above (iptables,
# ipset, dnsutils, aggregate).

CMD ["bash"]
