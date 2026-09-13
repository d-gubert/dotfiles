# dgubert.active-window

A clone of Omarchy's `omarchy.active-window` bar widget.
`omarchy plugin clone omarchy.active-window` made it, and the clone replaces
the built-in widget.

The widget hard-codes which string it shows, so the change needs a clone.
`shell.json` has no setting for it. The one setting the widget does read is
`maxWidth`, and that works the same in the clone:

```bash
omarchy bar set dgubert.active-window maxWidth 200 --json
```

## The local change

`ActiveWindow.qml` shows the app instead of the window title. The built-in
widget reads the title first and falls back to the app id. The clone reverses
that and shortens the app id. The tooltip still shows the full window title.

`appLabel()` does the shortening:

| App id | Label |
| --- | --- |
| `org.wezfurlong.wezterm` | `wezterm` |
| `chrome-web.whatsapp.com__-Default` | `web.whatsapp.com` |
| `chrome-nngceckbapebfimnlniiiahkandclblb-Default` | the window title |
| `Alacritty` | `Alacritty` |

A reverse-DNS id keeps its last segment. Chromium names a `--app=` window
`chrome-<encoded url>-Default` and encodes every `/` of the url as `_`, so the
host survives the trim and identifies the web app. A Chrome extension app has
no host in that position, and the window title names it instead.

## To re-sync after an Omarchy update

A clone does not follow the packaged widget, so bring the changes over by hand:

```bash
diff -u /usr/share/omarchy/shell/plugins/bar/widgets/ActiveWindow.qml \
  ~/.config/omarchy/plugins/dgubert.active-window/ActiveWindow.qml
```

Only the `LOCAL CHANGE` block and the three lines that read `label` must
survive. To start over, delete this directory and clone the widget again.

## After you edit this file

The shell watches `~/.config/omarchy/plugins/` and reloads plugin code on save,
but it does not follow the symlinks that stow puts there. Apply an edit with:

```bash
omarchy restart shell
```
