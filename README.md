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
| [homebrew](https://brew.sh) | Package manager | install script |
| [stow](https://www.gnu.org/software/stow) | Dotfiles symlink manager | brew |
| [brave-browser](https://brave.com) | Brave Browser | install script |
| [enpass](https://www.enpass.io) | Password manager | apt (Linux) / brew cask (macOS) |
| [zsh](https://www.zsh.org) | Shell | brew |
| [oh-my-zsh](https://ohmyz.sh) | Zsh framework | install script |
| [powerlevel10k](https://github.com/romkatv/powerlevel10k) | Zsh theme and prompt | git |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | brew |
| [btop](https://github.com/aristocratsbit/btop) | System resource monitor | brew |
| [docker](https://docs.docker.com/engine) | Container runtime | install script |
| [ffmpeg](https://ffmpeg.org) | Audio/video processing | brew |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | brew |
| [glow](https://github.com/charmbracelet/glow) | Markdown renderer for the terminal | brew |
| [jq](https://jqlang.org) | JSON processor | brew |
| [fd](https://github.com/sharkdp/fd) | Fast `find` replacement | brew |
| [kanata](https://github.com/jtroo/kanata) | Software keyboard remapper | brew |
| [neovim](https://neovim.io) | Text editor | brew |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep replacement (`rg`) | brew |
| [wezterm](https://wezterm.org) | GPU-accelerated terminal emulator | apt (Fury repo, Linux) / brew cask (macOS) |
| [herdr](https://herdr.dev) | Terminal workspace manager for AI coding agents | brew |
| [i3](https://i3wm.org) (Linux only) | Tiling window manager, with dependencies below | apt |

#### i3 dependencies (Linux only)

| Dependency | Description |
| -------- | ------------- |
| [maim](https://github.com/naelstrof/maim) | Screenshot tool |
| [pulseaudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) | Audio control |
| [playerctl](https://github.com/altdesktop/playerctl) | Media player control |
| [xserver-xorg-input-libinput](https://wiki.debian.org/InputDevices) | X11 input driver |
| [xinput](https://www.x.org/wiki/) | X11 input device utility |
| [network-manager-applet](https://gitlab.gnome.org/GNOME/network-manager-applet) | i3 tray icon (`nm-applet`) |
| [blueman](https://github.com/blueman-project/blueman) | Bluetooth manager |
| [arandr](https://christian.amsuess.com/tools/arandr/) | GUI front-end for xrandr (display configuration) |
| [xclip](https://github.com/astrand/xclip) | Clipboard CLI tool |
| [slop](https://github.com/naelstrof/slop) | Screen area selector |
| [rofi](https://github.com/davatorium/rofi) | General purpose menu selector |

#### Fonts (Nerd Fonts)

| Name | Installed via |
| - | - |
| [font-fira-code-nerd-font](https://www.programmingfonts.org/#firacode) | brew |

#### Oh-My-Zsh plugins

| Plugin | Description |
| -------- | ------------- |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like command suggestions |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Shell syntax highlighting |
| [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) | Better vi mode for zsh |
| [zsh-autopair](https://github.com/jeffreytse/zsh-autopair) | Auto closes pairs of symbols |

### Development

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [ast-grep](https://ast-grep.github.io) | AST-based code search and rewrite (`sg`) | brew |
| [dvm](https://github.com/justjavac/dvm) | Deno version manager | install script |
| [gh](https://cli.github.com) | GitHub CLI | brew |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git | brew |
| [meteor](https://www.meteor.com) | Full-stack JavaScript framework | install script |
| [node](https://nodejs.org) | JavaScript runtime | volta |
| [tealdeer](https://github.com/dbrgn/tealdeer) | Fast `tldr` client | brew |
| [vi-mongo](https://github.com/nicholasgasior/vi-mongo) | MongoDB TUI | brew |
| [volta](https://volta.sh) | Node.js toolchain manager | install script |

### Utilities (Optional)

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [carapace](https://carapace.sh) | Multi-shell completion generator | brew |
| [jwt-ui](https://github.com/jwt-rs/jwt-ui) | JWT TUI codec | brew |
| [lazyjira](https://github.com/textfuel/jiratui) | Jira TUI client | brew |
| [tree-sitter](https://tree-sitter.github.io) | Parser generator and incremental parsing | brew |
| [spotatui](https://github.com/LargeModGames/spotatui) | Spotify TUI | prebuilt installer |

### Standalone (not part of `all`/`essential`/`development`/`utilities`)

These have a `make install-<tool>` target but aren't pulled in by any aggregate target above — install them individually if you want them.

| Tool | Description | Installed via |
| ------ | ------------- | --------------- |
| [alacritty](https://github.com/alacritty/alacritty) | GPU-accelerated terminal emulator | apt (Linux) / brew cask (macOS) |
| [tmux](https://github.com/tmux/tmux) | The OG terminal multiplexer | brew |
| [zellij](https://zellij.dev) | Terminal multiplexer | brew |
| [rgx](https://github.com/brevity1swos/rgx) | Regex TUI | brew |
| [sttr](https://github.com/abhimanyu003/sttr) | String conversion CLI | brew |

#### Tmux plugins

| Plugin | Description |
| -------- | ------------- |
| [TPM](https://github.com/tmux-plugins/tpm) | Tmux Plugin Manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Sensible defaults for Tmux |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Save and restore sessions |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | Better copy-mode |
| [catppuccin](https://github.com/catppuccin/tmux) | Catppuccin for Tmux |

---

## Claude Code

### `tmux-window-status` plugin

A local [Claude Code plugin](https://code.claude.com/docs/en/plugins-reference) that prefixes the current tmux window name with a glyph while Claude waits for you — `● ` when it finishes a turn, `🔔 ` when it needs permission — and clears it once you reply. Tweak the glyphs in the plugin's `scripts/tmux-window-status.sh`.

- **Plugin:** `ubuntu/.claude/skills/tmux-window-status/` (hooks + script). It's dropped into the config dir's `skills/`, so Claude Code auto-loads it as `tmux-window-status@skills-dir` — no marketplace or install step, and nothing added to `~/.claude/settings.json`.
- **tmux side:** `ubuntu/.tmux.conf` splices a `@status_glyph` user option into the catppuccin window label
