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

# Neither the lifecycle scripts nor the egress firewall are copied into the
# image: this whole directory is bind-mounted read-only at /opt/devbox, so
# postStartCommand runs them straight from there and edits take effect on a
# restart, no rebuild. The firewall's tooling is installed above (iptables,
# ipset, dnsutils, aggregate).

CMD ["bash"]
