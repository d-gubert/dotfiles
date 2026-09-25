# Omarchy (Arch)

The `arch/` package targets [Omarchy](https://omarchy.org). `make` selects it when `/etc/os-release` names `arch` in `ID` or `ID_LIKE`.

## Packages

Arch does not use Homebrew. `mk/omarchy.mk` installs packages with `omarchy pkg add` and `omarchy pkg aur add`.

Three tools differ from the tables in the [README](../README.md#software). `gh` is `github-cli`, `carapace`,
`kanata` and `enpass` come from the AUR, and `lazyjira` has no
Arch package at all, so `make` reports it and installs the rest. Node comes
from mise instead of volta, and i3 is not installed because Omarchy runs
Hyprland.

Omarchy ships zoxide in `omarchy-base.packages`, so `common/.zshrc` loads zoxide on Arch and not the `z` plugin.

## Desktop preferences

Omarchy ships its own defaults for Hyprland, the shell and the terminal. Only the files that differ from those defaults live here, stowed from `arch/`:
`make stow` links each file on its own — `--no-folding` keeps the rest of `~/.config/hypr/` as real files that Omarchy still owns.

> [!WARNING]
> `omarchy refresh` and update migrations write through these symlinks into the repo. Run `git status` after an `omarchy update`.

The theme, the background and the screensaver flag are not config files. Omarchy keeps them in `~/.local/state/omarchy/`, so `make omarchy-prefs` sets them through the commands that own that state:

```sh
make omarchy-prefs   # Catppuccin theme, Totoro background, screensaver off
```

> [!NOTE]
> Keep the Lua config in `arch/.config/hypr/*.lua` in sync with the [Ubuntu Hyprland config](hyprland-ubuntu.md).
