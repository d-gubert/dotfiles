# dotfiles

Me dotfiles.

## Quick start on a new machine

### One-liner bootstrap

```sh
wget -qO- https://raw.githubusercontent.com/d-gubert/dotfiles/main/scripts/bootstrap.sh | bash
```

This clones the repo to `~/dev/dotfiles`, installs git first if needed, and runs `make all`.

### Manual setup

#### 1. Clone this repo

```sh
git clone https://github.com/d-gubert/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
```

#### 2. Install software

```sh
# Install everything
make all

# Or install by category
make essential       # core tools, shell, window manager
make development     # dev runtimes and CLI tools
make utilities       # optional quality-of-life tools
```

Individual packages can also be installed on their own:

```sh
make install-neovim
make install-zsh     # also installs oh-my-zsh and all plugins
```

##### 2.1 Stow

Stow would error out if directories already exist and are not owned by it, so we actually run stow as the first step in `make`.

If you add other configuration files to the `ubuntu` directory, you can get stow to manage them as well by running `make stow`.

Stow is usually used by having one directory for each software you want to manage, with the internal structure of that directory being mirrored in the `target`. I didn't like that, so I just threw all config files into the `ubuntu` directory, then I can stow everything there to my home directory.

---

## Software

### Essential

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [alacritty](https://github.com/alacritty/alacritty) | GPU-accelerated terminal emulator | apt |
| [homebrew](https://brew.sh) | Package manager | install script |
| [zsh](https://www.zsh.org) | Shell | brew |
| [oh-my-zsh](https://ohmyz.sh) | Zsh framework | install script |
| [powerlevel10k](https://github.com/romkatv/powerlevel10k) | Zsh theme | git |
| [zellij](https://zellij.dev) | Terminal multiplexer | brew |
| [kanata](https://github.com/jtroo/kanata) | Software keyboard remapper | brew |
| [i3](https://i3wm.org) | Tiling window manager | apt |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | brew |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep replacement (`rg`) | brew |
| [neovim](https://neovim.io) | Text editor | brew |
| [stow](https://www.gnu.org/software/stow) | Dotfiles symlink manager | brew |
| [gh](https://cli.github.com) | GitHub CLI | brew |
| [glow](https://github.com/charmbracelet/glow) | Markdown renderer for the terminal | brew |
| [jq](https://jqlang.org) | JSON processor | brew |
| [arandr](https://christian.amsuess.com/tools/arandr/) | GUI front-end for xrandr (display configuration) | apt |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | brew |
| [xclip](https://github.com/astrand/xclip) | Clipboard CLI tool | apt |
| [docker](https://docs.docker.com/engine) | Container runtime | install script |
| [btop](https://github.com/aristocratsbit/btop) | System resource monitor | brew |
| [tmux](https://github.com/tmux/tmux) | The OG terminal multiplexer | brew |
| [ffmpeg](https://ffmpeg.org) | Audio/video processing | brew |

#### Oh-My-Zsh plugins

| Plugin | Description |
| -------- | ------------- |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like command suggestions |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Shell syntax highlighting |
| [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) | Better vi mode for zsh |
| [zsh-autopair](https://github.com/jeffreytse/zsh-autopair) | Auto closes pairs of symbols |

#### Tmux plugins

| Plugin | Description |
| -------- | ------------- |
| [TPM](https://github.com/tmux-plugins/tpm) | Tmux Plugin Manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Sensible defaults for Tmux |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Save and restore sessions |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | Better copy-mode |
| [catppuccin](https://github.com/catppuccin/tmux) | Catppuccin for Tmux |

### Development

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [ast-grep](https://ast-grep.github.io) | AST-based code search and rewrite (`sg`) | brew |
| [dvm](https://github.com/justjavac/dvm) | Deno version manager | install script |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git | brew |
| [meteor](https://www.meteor.com) | Full-stack JavaScript framework | install script |
| [tealdeer](https://github.com/dbrgn/tealdeer) | Fast `tldr` client | brew |
| [vi-mongo](https://github.com/nicholasgasior/vi-mongo) | MongoDB TUI | brew |
| [volta](https://volta.sh) | Node.js toolchain manager | install script |

### Utilities (Optional)

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [jwt-ui](https://github.com/jwt-rs/jwt-ui) | JWT TUI codec | brew |
| [lazyjira](https://github.com/textfuel/jiratui) | Jira TUI client | brew |
| [spotatui](https://github.com/LargeModGames/spotatui) | Spotify TUI | brew |
| [carapace](https://carapace.sh) | Multi-shell completion generator | brew |
| [tree-sitter](https://tree-sitter.github.io) | Parser generator and incremental parsing | brew |

---

## Claude Code

### `tmux-window-status` plugin

A local [Claude Code plugin](https://code.claude.com/docs/en/plugins-reference) that prefixes the current tmux window name with a glyph while Claude waits for you — `● ` when it finishes a turn, `🔔 ` when it needs permission — and clears it once you reply. Tweak the glyphs in the plugin's `scripts/tmux-window-status.sh`.

- **Plugin:** `ubuntu/.claude/skills/tmux-window-status/` (hooks + script). It's dropped into the config dir's `skills/`, so Claude Code auto-loads it as `tmux-window-status@skills-dir` — no marketplace or install step, and nothing added to `~/.claude/settings.json`.
- **tmux side:** `ubuntu/.tmux.conf` splices a `@status_glyph` user option into the catppuccin window label
