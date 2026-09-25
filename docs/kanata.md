# kanata

[kanata](https://github.com/jtroo/kanata) is the software keyboard remapper. `make install-kanata` installs it, with the permissions and the service that each OS needs.

## Permissions

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

On macOS kanata needs Karabiner's VirtualHIDDevice driver instead. Each kanata
release supports one driver version, and its release notes name it.
`make install-kanata` runs `scripts/kanata-macos.sh`, which installs that
version from the standalone pkg (`VHID_VERSION` in the script) and requests
the driver activation. Two approvals stay manual:

1. Allow the driver under System Settings > General > Login Items &
   Extensions > Driver Extensions.
2. Add the kanata binary under System Settings > Privacy & Security > Input
   Monitoring. Add the real file, `readlink -f /opt/homebrew/bin/kanata`, not the
   symlink. The path contains the version, so do this again after each
   `brew upgrade kanata`.

Do not install Karabiner-Elements. It bundles a newer driver, and kanata then
logs `connect_failed asio.system:2` and releases the keyboard. The script
uninstalls the cask if it finds it.

If the key below Esc types `§` and `±` in place of `` ` `` and `~`, macOS took
the virtual keyboard for an ISO keyboard. The script sets the type of the
virtual keyboard to ANSI in `/Library/Preferences/com.apple.keyboardtype`.
Restart the daemon or log out to apply the change.

## At login (Linux)

`<os>/.config/systemd/user/kanata.service` starts kanata at login and restarts
it if it dies. The `arch/` and `ubuntu/` copies differ only in the path to the
binary: `/usr/bin` on Arch, the brew prefix on Ubuntu. A *user* unit, not a
system one: kanata runs as you and reads your config from `~/.config/kanata`. `make install-kanata` enables it.

The unit is not tied to `graphical-session.target`, so kanata remaps the
keyboard on a plain TTY as well. Nothing here waits for `/dev/uinput` — the
module drop-in loads it at boot, long before any login. On Ubuntu, kanata
runs the same under i3 and Hyprland.

Check it with `systemctl --user status kanata`, and read its output with
`journalctl --user -u kanata`.

## At boot (macOS)

`system/Library/LaunchDaemons/` holds two root daemons, and
`make install-kanata` copies them to `/Library/LaunchDaemons` and loads them.
`local.dotfiles.karabiner-vhiddaemon` runs the daemon that talks to the
driver. `local.dotfiles.kanata` runs kanata with `~/.config/kanata/kanata.kbd`.
Both must run as root. The script also stops a `brew services` kanata job,
because two kanata processes cannot share the keyboard.

Check them with `sudo launchctl print system/local.dotfiles.kanata`, and read
the kanata output in `/Library/Logs/kanata.log`. After a config change, run
`sudo launchctl kickstart -k system/local.dotfiles.kanata`.

## Home-row mods

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
