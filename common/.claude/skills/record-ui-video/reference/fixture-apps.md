# Customize a fixture app

Read this when the recording must show an app that says or does something specific.

**Preferred — `rc-apps package`.** `rc-apps` is installed globally (run it as `rc-apps`, not
`yarn rc-apps`). Follow `tests/data/apps/app-packages/README.md`: copy the fixture's source (from its
`<details>` block) into a scratch dir **inside this repo**, edit it, run `rc-apps package`, and copy
the `dist/<name>_<version>.zip` out. Building from source is the right way — the bundle stays valid
and the app typechecks against the engine.

**Quick fallback — hand-edit the zip.** For a one-string change, a packaged app is one bundled JS
file plus `app.json`, so you can edit and re-zip without a rebuild:

1. `unzip` the app under `tests/data/apps/app-packages/`.
2. Edit the string in the bundle `.js` (e.g. a prevention reason), or its `i18n/*.json`. Give it a
   new `app.json` `id` (`crypto.randomUUID()`), `name`, and `nameSlug` so it reads well and does not
   clash with the original.
3. Re-zip from inside the unpacked dir: `zip -r -X ../<name>.zip .` (keep the hidden `.packagedby`).

Either way, install it in the spec with `installLocalTestPackage('<abs path to zip>')` and uninstall
in `afterAll`.
