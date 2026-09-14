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
| `ubuntu/` | Debian/Ubuntu only — i3, i3status, rofi, clipmenu, nushell, `.Xresources`, `.xprofile`, and the [Hyprland session](#hyprland-session-on-ubuntu) (hypr, waybar, mako) |
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
| [wezterm](https://wezterm.org) | GPU-accelerated terminal emulator | apt (Fury repo, Linux — the `wezterm-nightly` package, see [below](#wezterm-on-wayland)) / brew cask (macOS) |
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
| [hyprland](https://hypr.land) (Ubuntu only) | Wayland compositor, with the dependencies in [Hyprland session on Ubuntu](#hyprland-session-on-ubuntu) | apt |

#### Tmux plugins

| Plugin | Description |
| -------- | ------------- |
| [TPM](https://github.com/tmux-plugins/tpm) | Tmux Plugin Manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Sensible defaults for Tmux |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Save and restore sessions |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | Better copy-mode |
| [catppuccin](https://github.com/catppuccin/tmux) | Catppuccin for Tmux |

---

## Hyprland session on Ubuntu

Ubuntu runs i3 on X11. Hyprland is a second session beside it, not a replacement: gdm lists both, and the i3 config is untouched. Install it with:

```sh
make install-hyprland
```

Ubuntu 26.04 packages every piece, so that target is one `apt-get` call. `mk/debian.mk` lists what each package is for. Log out, pick "Hyprland" on the gdm gear menu, and log back in. To go back to i3, pick "i3" there.

### What the config holds

The files live in `ubuntu/.config/hypr/`, one per topic, sourced by `hyprland.conf`:

| File | Contents |
| ------ | ---------- |
| `env.conf` | Wayland hints for the toolkits, and the NVIDIA notes for this laptop |
| `monitors.conf` | One rule: every monitor takes its preferred mode, placed left to right |
| `input.conf` | The two keyboard layouts, the touchpad, the workspace gesture |
| `looknfeel.conf` | Catppuccin Mocha colors, no gaps, no rounding, flat animations |
| `bindings.conf` | Every keybinding, plus the resize mode and the system mode |
| `autostart.conf` | waybar, mako and the two clipboard watchers |
| `scripts/` | The screenshot, the screen recorder, the clipboard history, the layout toggle and the keybinding list |

waybar replaces i3bar and i3status (`ubuntu/.config/waybar/`), and mako is the notification daemon (`ubuntu/.config/mako/`). rofi 2.0 links against Wayland, so the same `ubuntu/.config/rofi/` theme serves both sessions.

The session starts no tray applet. waybar reads NetworkManager and BlueZ over D-Bus, so its `network` and `bluetooth` modules show the state on their own. A click opens `nmtui` in a terminal, or `blueman-manager`. The i3 session keeps `nm-applet` and `blueman-applet`.

The bindings repeat the i3 ones: `SUPER + J/K/L/;` moves the focus, `SUPER + SHIFT` of those moves the window, `SUPER + R` enters the resize mode, `SUPER + SHIFT + E` enters the system mode. Hyprland calls a mode a submap, and waybar shows the name of the active one in the bar. Only the terminal, the launcher and the browser have a launch key; the Rocket.Chat one is not ported.

Every binding is a `bindd`, which carries a description, the way `o.bind` does on Omarchy. `SUPER + ALT + K` lists them all in rofi, read from `hyprctl binds`, so the list can never drift from the config. A binding written as a plain `bind` is left out of the list on purpose — the `catchall` that swallows stray keys inside a mode is the only one.

The `SUPER + ALT` row holds the bindings Omarchy displaced, for the same reason it does on Arch: the home row took their keys. `J` toggles the window split, `L` toggles the layout, `K` opens the keybinding list. Two differ from Omarchy. Omarchy's layout toggle changes one workspace, while plain Hyprland keeps `general:layout` for the whole session, so the toggle is global here. Omarchy's keybinding menu is on `SUPER + SHIFT + K`, which moves a window down in this config, so the list moved to the `SUPER + ALT` row as well.

> [!NOTE]
> Keep this config and the Omarchy one in `arch/.config/hypr/*.lua` in sync. Omarchy reads a Lua config layer that plain Hyprland does not have, so the same preference is written twice, in two syntaxes.

### Screenshots and recording

`Print` selects an area, saves it under `~/Pictures/Screenshots/` and copies it to the clipboard. `SUPER + S` toggles a recording of a selected area into `~/Videos/Recordings/`. Both are the same keys as i3, and both scripts are ports of the i3 ones in `ubuntu/.config/i3/scripts/`:

| i3, on X11 | Hyprland, on Wayland |
| - | - |
| `maim -s -u` | `grim -g "$(slurp)"` |
| `slop -f '%x %y %w %h'` | `slurp`, which already prints `X,Y WxH` |
| `ffmpeg -f x11grab` | `wf-recorder -g` |
| `xclip -t image/png` | `wl-copy -t image/png` |

The recorder keeps the toggle, the state file and the `SIGINT` stop of the i3 version — `wf-recorder` also needs `SIGINT` to close the container, or the mp4 has no moov atom and will not play. It drops the PATH fix, because `wf-recorder` is in `/usr/bin` while the i3 script needs the brew `ffmpeg`. One limit is new: a recorded region has to stay on one monitor, because `wf-recorder` records one output.

`grimshot`, the packaged wrapper that would replace the screenshot script, depends on the `sway` package. That would put a second compositor on the machine to get one shell script, so the repo keeps its own script instead.

### wezterm on Wayland

Install `wezterm-nightly`, not `wezterm`. The tagged release, `20240203`, is from February 2024, and upstream has published nightlies only since then. That build hangs under Hyprland: `wezterm-gui` starts, answers spawn requests with a window id, and never maps the window on Wayland. The process then absorbs every later `wezterm` call, so nothing opens and nothing reports an error.

Two ways to see it, if it ever comes back:

```sh
# The hung process is a child of Hyprland, and holds a socket with no window.
ps -o pid,ppid,etime,args -C wezterm-gui
hyprctl clients | grep class

# A window maps at once on XWayland, which isolates the fault to the
# Wayland backend.
wezterm-gui --config enable_wayland=false start --always-new-process
```

### Clipboard history

`SUPER + V` opens the history in rofi, the same key and the same picker as i3. The keys are:

| Key | Action |
| - | - |
| `CTRL + J` / `CTRL + K` | Move down and up the list |
| `ENTER` or `CTRL + M` | Copy the entry back to the clipboard |
| `CTRL + D` | Remove the entry from the history |
| `ESCAPE` or `CTRL + C` | Cancel |

The arrows and the rofi defaults `CTRL + N` and `CTRL + P` still move the list.

The script takes each of those keys from its default rofi action first. rofi holds `CTRL + C` for `kb-secondary-copy`, `CTRL + K` for `kb-remove-to-eol`, `CTRL + D` for `kb-remove-char-forward` and `CTRL + J` for `kb-accept-entry`. A key bound twice stops rofi at startup, and the error window keeps the keyboard, which locks the session until you close it.

`cliphist` has no daemon. Two `wl-paste --watch` lines in `autostart.conf` run `cliphist store` on every copy, one for text and one for images. `ubuntu/.config/hypr/scripts/clipboard.sh` reads the history back.

> [!WARNING]
> `cliphist` writes the history to `~/.cache/cliphist/db`, so it survives a reboot. `clipmenu` keeps its history in `/dev/shm`, which the boot clears. A password you copy stays on disk until you remove it. Remove one entry with `CTRL + D` in the picker, or clear the whole history with `cliphist wipe`.

A password manager can mark a copy as sensitive, and `cliphist` then skips it. That covers the managers that set the hint, not every program.

### What differs from the i3 session

The bindings carry over. The rest is deliberately thinner than i3.

- **No monitor profiles.** i3 matches a monitor by EDID and applies a stored profile from `~/.config/i3/monitors/`. Hyprland places every monitor at its preferred mode, left to right. `monitors.conf` shows how to pin one if that is ever wrong.
- **No window rules.** The i3 `for_window` and `assign` lines are not ported. Windows tile where they open, and Rocket.Chat is not sent to workspace 7.
- **A shorter bar.** waybar shows the workspaces, the submap, the window title, network, Bluetooth, volume, battery, the tray and the clock. The i3status modules for load, CPU, temperature, memory, disk and the rc-watcher file are not there.
- **A different clipboard history.** `clipmenu` reads the X11 selection, so the Wayland session runs `cliphist` instead. The key is the same, and so is the picker. See [below](#clipboard-history).

`SUPER + CTRL + L` runs `hyprlock` with its built-in defaults. There is no idle timeout: nothing locks the screen on its own, because `hypridle` is not configured yet.

---

## Omarchy desktop preferences

Omarchy ships its own defaults for Hyprland, the shell and the terminal. Only the files that differ from those defaults live here, stowed from `arch/`:
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
