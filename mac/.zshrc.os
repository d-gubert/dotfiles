# macOS-specific shell settings. Sourced by common/.zshrc.
# The Linux counterpart lives in ubuntu/.zshrc.os — keep the two in sync.

# Used by mypr() and anything else that opens a URL or copies to the clipboard.
export OPEN_CMD="open"
export CLIP_CMD="pbcopy"

# Several tools default to ~/Library/Application Support on macOS and would
# silently ignore the configs common/ stows into ~/.config (lazygit and zellij
# in particular). Setting this explicitly makes both platforms behave the same.
export XDG_CONFIG_HOME="$HOME/.config"
