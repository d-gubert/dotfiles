# Hyprland session on Ubuntu

Ubuntu runs [i3](i3.md) on X11. Hyprland is a second session beside it, not a replacement: gdm lists both, and the i3 config is untouched. Install it with:

```sh
make install-hyprland
```

Ubuntu 26.04 packages every piece, so that target is one `apt-get` call. `mk/debian.mk` lists what each package is for. Log out, pick "Hyprland" on the gdm gear menu, and log back in. To go back to i3, pick "i3" there.

## What the config holds

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
> Keep this config and the [Omarchy](omarchy.md) one in `arch/.config/hypr/*.lua` in sync. Omarchy reads a Lua config layer that plain Hyprland does not have, so the same preference is written twice, in two syntaxes.

## Screenshots and recording

`Print` selects an area, saves it under `~/Pictures/Screenshots/` and copies it to the clipboard. `SUPER + S` toggles a recording of a selected area into `~/Videos/Recordings/`. Both are the same keys as i3, and both scripts are ports of the i3 ones in `ubuntu/.config/i3/scripts/`:

| i3, on X11 | Hyprland, on Wayland |
| - | - |
| `maim -s -u` | `grim -g "$(slurp)"` |
| `slop -f '%x %y %w %h'` | `slurp`, which already prints `X,Y WxH` |
| `ffmpeg -f x11grab` | `wf-recorder -g` |
| `xclip -t image/png` | `wl-copy -t image/png` |

The recorder keeps the toggle, the state file and the `SIGINT` stop of the i3 version — `wf-recorder` also needs `SIGINT` to close the container, or the mp4 has no moov atom and will not play. It drops the PATH fix, because `wf-recorder` is in `/usr/bin` while the i3 script needs the brew `ffmpeg`. One limit is new: a recorded region has to stay on one monitor, because `wf-recorder` records one output.

`grimshot`, the packaged wrapper that would replace the screenshot script, depends on the `sway` package. That would put a second compositor on the machine to get one shell script, so the repo keeps its own script instead.

## wezterm on Wayland

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

## Clipboard history

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

## What differs from the i3 session

The bindings carry over. The rest is deliberately thinner than i3.

- **No monitor profiles.** i3 matches a monitor by EDID and applies a stored profile from `~/.config/i3/monitors/`. Hyprland places every monitor at its preferred mode, left to right. `monitors.conf` shows how to pin one if that is ever wrong.
- **No window rules.** The i3 `for_window` and `assign` lines are not ported. Windows tile where they open, and Rocket.Chat is not sent to workspace 7.
- **A shorter bar.** waybar shows the workspaces, the submap, the window title, network, Bluetooth, volume, battery, the tray and the clock. The i3status modules for load, CPU, temperature, memory, disk and the rc-watcher file are not there.
- **A different clipboard history.** `clipmenu` reads the X11 selection, so the Wayland session runs `cliphist` instead. The key is the same, and so is the picker. See [Clipboard history](#clipboard-history).

`SUPER + CTRL + L` runs `hyprlock`, which reads `ubuntu/.config/hypr/hyprlock.conf`. hyprlock has no built-in defaults from v0.9 on: without that file it refuses to start and the session stays unlocked.

`hypridle` handles the idle timeouts, from `ubuntu/.config/hypr/hypridle.conf`. It locks the session after 9.5 minutes of no input, and it turns the outputs off 30 seconds later. The lock comes first on purpose: hyprlock must draw its surface before the screen sleeps. `hypridle` also locks before a suspend, so a lid close leaves no open session.

> [!WARNING]
> `dpms off` can leave `HDMI-A-1` dark, because the NVIDIA GPU drives that output. Cycle the output to recover it. Do not run `hyprctl reload`.
>
> ```sh
> hyprctl keyword monitor "HDMI-A-1, disable"
> hyprctl keyword monitor "HDMI-A-1, preferred, auto, 1"
> ```
