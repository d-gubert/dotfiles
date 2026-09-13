# dgubert.menu

A clone of Omarchy's `omarchy.menu` plugin. `omarchy plugin clone omarchy.menu`
made it, and the clone replaces the built-in menu.

The menu plugin hard-codes its key handler, so a key change needs a clone.
There is no setting for it in `shell.json`.

## The local change

`Menu.qml` adds three keys to the handler in `keyCatcher`:

| Key | Action |
| --- | --- |
| `Ctrl+K` | move the selection up, the same as `Up` |
| `Ctrl+J` | move the selection down, the same as `Down` |
| `Ctrl+M` | activate the selection, the same as `Return` |

Nothing else differs from the built-in plugin.

## To re-sync after an Omarchy update

A clone does not follow the packaged plugin, so bring the changes over by hand:

```bash
diff -ru /usr/share/omarchy/shell/plugins/menu ~/.config/omarchy/plugins/dgubert.menu
```

Only the `LOCAL CHANGE` comment and the three keys beside it must survive.
To start over, delete this directory and clone the plugin again.

## After you edit this file

The shell watches `~/.config/omarchy/plugins/` and reloads plugin code on save,
but it does not follow the symlinks that stow puts there. Apply an edit with:

```bash
omarchy restart shell
```
