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

If you add other configuration files, you can get stow to manage them as well by running `make stow`.

Stow is usually used by having one directory for each software you want to manage, with the internal structure of that directory being mirrored in the `target`. I didn't like that, so config files are grouped by *operating system* instead:

| Package | Contents |
| --------- | ---------- |
| `common/` | Everything OS-agnostic — zsh, tmux, wezterm, nvim, yazi, zellij, lazygit, herdr, kanata, starship, git, `.claude/` |
| `ubuntu/` | Debian/Ubuntu only — i3, i3status, rofi, clipmenu, nushell, `.Xresources`, `.xprofile` |
| `arch/` | Arch/Omarchy only — Wayland clipboard, mise toolchain wiring, and the [Omarchy desktop config](#omarchy-desktop-preferences) |
| `mac/` | macOS only |

`make` stows `common` plus the package for this OS, so a macOS machine never gets i3 or X11 config dropped into its home directory. `uname` only separates Darwin from Linux, so the two Linux packages are split on `/etc/os-release` instead: `ID` or `ID_LIKE` naming `arch` selects `arch/`, anything else gets `ubuntu/`. Omarchy reports `ID=omarchy` with `ID_LIKE=arch`, which is why the match reads both fields. The target uses `stow -R`, which also cleans up stale symlinks when a file moves between packages.

Prefer branching inside a shared config over copying it into both OS packages — most tools already have a mechanism for it (`.zshrc` checks `uname`, `.tmux.conf` has `if-shell`, `.wezterm.lua` has `wezterm.target_triple`). Only copy the whole file when the format has no conditionals, as with `alacritty.toml`.

For shell settings, each OS package ships a `.zshrc.os` fragment that `common/.zshrc` sources. That's where `$OPEN_CMD` (`xdg-open` vs `open`) and `$CLIP_CMD` (`xclip` on X11, `wl-copy` on Wayland, `pbcopy` on macOS) are defined, along with the per-OS toolchain wiring — Homebrew's `shellenv` on Ubuntu and macOS, `mise activate` on Arch — use those variables rather than hardcoding either tool.

---

## Software

The "Installed via" column below describes Ubuntu and macOS, which both use
Homebrew. Arch does not. `make` picks a package backend from the OS family:

| Family | Backend | Bootstrap |
| ------ | ------- | --------- |
| `darwin`, `debian` | Homebrew, in `mk/brew.mk` | installs brew first |
| `arch` | `omarchy pkg add` and `omarchy pkg aur add`, in `mk/omarchy.mk` | none needed |

A backend defines `PKG_PREREQ`, `PKG_INSTALL_CMD` and any `PKG_<tool>` name
overrides. The main Makefile reads those names and never mentions a package
manager. To add a tool that is only a package name, put it in one of the
`*_TOOLS` lists and add a `PKG_<tool>` line wherever the name differs.

Three tools differ from the table on Arch. `gh` is `github-cli`, `carapace`,
`kanata`, `enpass` and `brave-browser` come from the AUR, and `lazyjira` has no
Arch package at all, so `make` reports it and installs the rest. Node comes
from mise instead of volta, and i3 is not installed because Omarchy runs
Hyprland.

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
| [kanata](https://github.com/jtroo/kanata) | Software keyboard remapper | package on Arch, brew elsewhere (see [kanata permissions](#kanata-permissions) below) |
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

#### kanata permissions

kanata reads the keyboard through `/dev/input` and writes the remapped keys back
through `/dev/uinput`. Both belong to root, so without setup kanata exits with:

```
[ERROR] Failed to open the output uinput device. Make sure you added the user
executing kanata to the 'uinput' group [...]
[ERROR] Permission denied (os error 13)
```

On Linux `make install-kanata` runs `uinput-config` first, which creates the
`uinput` system group, adds you to `input` and `uinput`, installs
`system/etc/udev/rules.d/99-uinput.rules` so the node is `root:uinput` mode
0660, and installs `system/etc/modules-load.d/uinput.conf` so the module loads
at boot. Log out and back in for the group change to take effect, or run
`newgrp uinput -c kanata` once in the current shell. See the [kanata Linux
setup docs](https://github.com/jtroo/kanata/blob/main/docs/setup-linux.md).

On macOS kanata needs Karabiner's VirtualHIDDevice driver instead. The target
installs Karabiner-Elements and prints what you still have to approve under
System Settings > Privacy & Security.

#### kanata home-row mods

`common/.config/kanata/kanata.kbd` holds the layer, and each OS package holds
its own `mods.kbd` with the aliases. kanata resolves an `include` against the
directory of the config file it opened, which is `~/.config/kanata` and not
this repository, so stow decides which variant kanata reads.

Only one thing differs. The Debian and macOS copies wrap each alias in
`(multi f24 ...)`, which presses a spare key with the modifier so the desktop
never sees a lone modifier tap and does not open the GNOME overview. That
wrapper depends on keycode 202 having no keysym. A current xkeyboard-config
gives it `F24`, the terminal writes `\E[24;2~` for it, zsh-vi-mode reads the
leading `ESC`, and the prompt drops to NORMAL mode on every home row letter.
So the Arch copy has no wrapper. Test a machine with
`xkbcli compile-keymap --layout us | grep -A3 '<FK24>'` before you copy one
variant over another.

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

`common/.zshrc` also loads the built-in `copybuffer`, `copyfile`, `copypath`,
`gh` and `git` plugins, and one of `z` or [zoxide](https://github.com/ajeetdsouza/zoxide).
Both define a `z` command, so the file loads the plugin only when zoxide is
absent. Omarchy ships zoxide in `omarchy-base.packages`, so Arch gets zoxide
and the other platforms keep the plugin. Install zoxide anywhere to switch.

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

## Omarchy desktop preferences

Omarchy ships its own defaults for Hyprland, the shell and the terminal. Only the files that differ from those defaults live here, stowed from `arch/`:

| File | What it changes |
| ------ | ----------------- |
| `.config/hypr/monitors.lua` | monitor scale `0.8`, so the 13.3" 1080p panel gets a logical size of 2400x1350 and the interface shrinks by a fifth. `GDK_SCALE` stays `1` because it takes integers only |
| `.config/hypr/input.lua` | touchpad natural scrolling |
| `.config/hypr/bindings.lua` | `SUPER + {j,k,l,;}` move the focus left, down, up and right, and `SUPER + B` opens the browser — the same keys as my i3 config |
| `.config/hypr/looknfeel.lua` | `gaps_in` and `gaps_out` both `0`. The border still marks the focused window. Opacity `1 1` for the terminal, so the wallpaper does not show through the text |
| `.config/alacritty/alacritty.toml` | font size `8` |
| `.config/omarchy/shell.json` | adds the `omarchy.active-window` widget to the left of the bar, after the workspaces. It prints the title of the focused window |
| `.config/omarchy/shell.toml` | bar font base size `11` |
| `.config/xdg-terminals.list` | wezterm as the default terminal for `xdg-terminal-exec`, which is what `$TERMINAL` points at |
| `.local/share/applications/org.wezfurlong.wezterm.desktop` | adds the `X-TerminalArg*` keys the wezterm package leaves out, so `xdg-terminal-exec --dir` and `--app-id` reach wezterm |

`SUPER + {j,k,l}` displaced three Omarchy bindings. `bindings.lua` unbinds each one, then puts it back: toggle split on `SUPER + ALT + J`, toggle workspace layout on `SUPER + ALT + L` and the keybindings menu on `SUPER + SHIFT + K`.

`make stow` links each file on its own — `--no-folding` keeps the rest of `~/.config/hypr/` as real files that Omarchy still owns.

> [!WARNING]
> `omarchy refresh` and update migrations write through these symlinks into the repo. Run `git status` after an `omarchy update`.

The theme, the background and the screensaver flag are not config files. Omarchy keeps them in `~/.local/state/omarchy/`, so `make omarchy-prefs` sets them through the commands that own that state:

```sh
make omarchy-prefs   # Catppuccin theme, Totoro background, screensaver off
```

---

## Dev containers — `devbox`

`containers/devcontainer/` holds one devcontainer definition for *every* checkout on the machine, and `scripts/devbox` runs it over whatever directory you're in:

```sh
cd ~/dev/RocketChat/worktrees/main
devbox up          # build/start a container with this checkout mounted
devbox claude      # Claude Code, --dangerously-skip-permissions, behind an egress firewall
devbox shell       # zsh in there
```

Nothing is added to the repo being worked on — no `.devcontainer/`, no committed compose file. The container is generic (Node/Yarn/pnpm through Volta); a repo's own setup lives in a **profile** under `containers/devcontainer/projects/<name>/`, picked by matching your path. Caches and logins (yarn, Claude Code, `gh`, Playwright browsers) are shared volumes, so you download and log in once for all checkouts.

Egress is default-deny, re-applied on every start, which is what makes `--dangerously-skip-permissions` a bounded risk. See [`containers/devcontainer/README.md`](containers/devcontainer/README.md).

---

## Claude Code

### `tmux-window-status` plugin

A local [Claude Code plugin](https://code.claude.com/docs/en/plugins-reference) that prefixes the current tmux window name with a glyph while Claude waits for you — `● ` when it finishes a turn, `🔔 ` when it needs permission — and clears it once you reply. Tweak the glyphs in the plugin's `scripts/tmux-window-status.sh`.

- **Plugin:** `common/.claude/skills/tmux-window-status/` (hooks + script). It's dropped into the config dir's `skills/`, so Claude Code auto-loads it as `tmux-window-status@skills-dir` — no marketplace or install step, and nothing added to `~/.claude/settings.json`.
- **tmux side:** `common/.tmux.conf` splices a `@status_glyph` user option into the catppuccin window label
