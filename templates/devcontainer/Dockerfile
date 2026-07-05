FROM node:22

ARG TZ
ENV TZ="$TZ"

# Basic dev tooling plus the packages init-firewall.sh needs
# (iptables/ipset/iproute2/dnsutils/aggregate/jq) and the GitHub CLI.
RUN apt update && apt install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  curl \
  wget \
  && rm -rf /var/lib/apt/lists/*

# Signal to Claude (and to you) that this shell is inside the sandbox.
ENV DEVCONTAINER=true

# Persist shell history on a mounted volume.
RUN mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R node /commandhistory

# Create workspace and Claude config dirs owned by the non-root user.
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude
WORKDIR /workspace

# git-delta for nicer diffs (optional, matches a common host setup).
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

USER node

# Install Claude Code globally into a user-writable prefix.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh
ENV EDITOR=nvim
ENV VISUAL=nvim

# zsh + a light powerlevel10k, with fzf keybindings and persisted history.
# The `claude` alias runs with permissions bypassed by default — the whole
# container is the sandbox, so agents work freely here. Use `claude-ask` when
# you want the normal permission prompts back.
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "export PROMPT_COMMAND='history -a'" \
  -a "export HISTFILE=/commandhistory/.bash_history" \
  -a "alias claude='claude --dangerously-skip-permissions'" \
  -a "alias claude-ask='command claude'" \
  -x

RUN npm install -g @anthropic-ai/claude-code

# Install the firewall script and grant the node user passwordless sudo for
# just that one command (needed by postCreateCommand).
USER root
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
