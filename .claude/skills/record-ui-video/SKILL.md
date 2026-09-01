---
name: record-ui-video
description: Record a screen video of a Rocket.Chat UI flow (a demo, a repro, a walkthrough) by driving the real app with Playwright and transcoding to MP4. Use when the user asks to record, film, capture, or screen-record a scenario in apps/meteor.
---

# Record a UI video

Drive the real `apps/meteor` app with a throwaway Playwright spec that forces video on, then
transcode the recording to MP4 if `ffmpeg` is available. This reuses the e2e fixtures, so you never log in through a form
or wire up auth by hand.

## The idea in one line

The e2e stack already records video (`retain-on-failure`); override it to `on`, drive the scenario
on the default `page`, and the video is saved whether the run passes or fails.

## Scripts

Four scripts in `scripts/` next to this file replace the environment reads. Run them instead of
probing `ps`, `ss`, `/proc`, or the browser cache yourself. Each one accepts `--help`.

| Script | What it answers |
| --- | --- |
| `preflight.sh` | Is everything in place to record? What is missing, and who fixes it? |
| `find-server.sh` | Which server serves THIS worktree, on which port, against which database? |
| `record.sh` | Run the spec, transcode to MP4, extract frames to verify. |
| `rc-api.sh` | One-line authenticated admin REST call, for setup and cleanup checks. |

The scripts print absolute paths, because `cd apps/meteor` in one Bash call persists into the next
one and breaks a relative path.

## Steps

### 1. Run the preflight

```bash
.claude/skills/record-ui-video/scripts/preflight.sh
```

It checks the workspace, `node_modules`, stale package builds, `chromium-headless-shell`, `ffmpeg`,
and the server, then exits 0 when ready or 1 with a list of fixes split into two groups: the ones it
can run and the ones only the user can do.

If it reports missing prerequisites, ask the user which way they want to go before you touch
anything. Use `AskUserQuestion` with the script's own two groups as the options:

- **Let the skill install them** — you run `preflight.sh --install`. It installs dependencies,
  builds stale packages, and downloads the browser, then re-checks.
- **The user installs them** — you print the commands and wait.

Two fixes are slow (`yarn build`, a browser download), so never run `--install` unasked.

The server is always the user's call. The script cannot start one safely: a port and a database name
are choices with consequences. Two servers on one database, on different releases, corrupt each
other through migrations.

> Warning: a server from another worktree serves *other code*. `preflight.sh` and `find-server.sh`
> both report the worktree and branch behind each port. Check that the branch is yours before you
> record.

### 2. Write a throwaway spec

Copy `template.spec.ts` (next to this file) into `apps/meteor/tests/e2e/demos/<name>-demo.spec.ts`
and edit the scenario. It is a spec, not a suite: assertions only gate the recording. Keep these
parts unchanged — they are what make the video work:

- `test.use({ channel, storageState, viewport, video: { mode: 'on', size } })` — `mode: 'on'` keeps
  the video on pass or fail; `size` matches `viewport`. `channel: 'chromium-headless-shell'` avoids a
  gray strip in the recording (see "The gray strip" below).
- `storageState: Users.user1.state` — logs the page in as `user1` with no login screen. Login
  tokens are deterministic: `base64(sha256(username))`, pre-seeded in the DB. Pick any of
  `Users.user1`, `Users.user2`, … from `tests/e2e/fixtures/userStates.ts`.
- The `api` fixture (from `tests/e2e/utils/test.ts`) is the **admin** REST context. Use it for
  setup: `api.post('/users.setStatus', { status: 'online', username })`, settings, app modes.
- `showPointer(page)` and `beat(page)` — a visible cursor dot and deliberate pauses, so the video
  reads. Keep them.
- `glideClick(page, locator)` — moves the cursor to a target in steps, then clicks. Use it for a
  click the viewer watches. See "Smoother motion" below.

### 3. Record one screen, not two

Most flows need one actor's screen. Put the other side online by API
(`users.setStatus`) instead of opening a second browser.

### 4. Run it

```bash
.claude/skills/record-ui-video/scripts/record.sh tests/e2e/demos/<name>-demo.spec.ts
```

It reads the port and `MONGO_URL` from the server of this worktree, sets `IS_EE=true`, clears the
spec's earlier output, runs the spec, copies the `webm`, transcodes an `mp4`, and extracts check
frames. It prints the path of every output plus the full log.

Useful options: `--name` for the output basename, `--out-dir` for the destination, `--frame-every N`
for the check-frame interval, `--port` / `--mongo-url` to override discovery.

The run takes ~30 s. `record.sh` exits with the spec's own exit code and warns you when the video
records a failed run.

### 5. Verify the frames before you hand the video over

`record.sh` prints a frames directory. `Read` a few of those PNGs. Confirm the flow, and confirm
there is no gray strip.

### 6. Clean up

Keep the spec unless the user asks you to delete it — they may want another take. Confirm no app
you installed is left behind:

```bash
.claude/skills/record-ui-video/scripts/rc-api.sh GET /api/apps/installed
```

The `.playwright` output dir is git-ignored; leave it.

## Leftover state shows up on screen

The database keeps what earlier runs wrote. A DM shows every prevented-call card from every take,
and a call history shows every old row. The video still reads, but a clean screen reads better.
Clear the state before the take with `rc-api.sh`, for example:

```bash
scripts/rc-api.sh POST /api/v1/rooms.cleanHistory \
  '{"roomId":"<id>","oldest":"2000-01-01T00:00:00.000Z","latest":"2100-01-01T00:00:00.000Z"}'
```

Tell the user what the screen will show if you do not clear it.

## Smoother motion

Playwright's video recorder has **no fps setting** and caps around 25 fps (it captures a frame only
when the page compositor changes, and drops frames during idle beats). `video.size` sets resolution,
not frame rate. So you cannot ask the recorder for 60 fps.

Most perceived choppiness is the pointer. A raw `locator.click()` teleports the cursor, so the
screencast captures a jump, not a glide. The template's `glideClick(page, locator, steps)` helper
interpolates the move — each `steps` move is a mouse event the compositor renders, so the recorder
has real intermediate frames. Raise `steps` for a slower, smoother glide. This does not change the
file's fps; it removes the teleports that read as choppy.

## The gray strip

Playwright's **new headless mode** pads the recorded video with a solid gray strip: it captures only
the top of the viewport and fills the rest with gray (microsoft/playwright#36032, open against
Playwright 1.52). The strip does not scale with `video.size`, so matching `size` to `viewport` does
not remove it and shrinking `size` only shifts it.

The fix is to record with the **legacy headless-shell** browser, which has no such artifact:

```ts
test.use({ channel: 'chromium-headless-shell', /* … */ });
```

It records the full viewport, so `video.size` matches `viewport` and nothing is cropped. This is a
separate download; `preflight.sh` checks for it and `preflight.sh --install` fetches it.

The repo's `playwright.config.ts` sets `channel: 'chromium'` for the whole suite; the `test.use` in
the spec overrides it for the recording only. The headless-shell still drives fake media streams, so
voice and video calls record fine.

## Locator hygiene (this is what fails runs)

The scenario usually works on the first try; a locator matching too much is what breaks it.

- **Repeated content.** A DM that ran before holds old cards. `getByText('…')` then matches many
  and strict mode throws. Scope to the newest message: `home.content.lastUserMessage`, asserted with
  `toContainText`.
- **Contextual bars / panels.** Scope to the named dialog, e.g.
  `page.getByRole('dialog', { name: 'Call info' })`, not the whole page (the list behind it also
  holds the text).
- **History rows** are `role="link"`; newest is first. `.filter({ hasText }).first()`.
- **Lingering overlays.** A call dialer stays open after a refused call and covers the navbar. Close
  it (`widget.btnClose`) before you navigate.

## Page objects worth knowing (`tests/e2e/page-objects/`)

`HomeChannel` exposes `navbar.openChat(name)`, `composer.inputMessage`, `content.btnVoiceCall`,
`content.messageById(id)`, `content.lastUserMessage`, and `voiceCalls.widget` /
`voiceCalls.roomSection` (see `fragments/voice-calls.ts`: `controls.call/accept/reject/hangup/cancel`,
`initiateCall()`, `acceptCall()`). Reuse them instead of raw locators.

## Customize a fixture app

You need a custom app when the recording must show an app saying or doing something specific.

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

## Facts that save a re-research

- Playwright config: `apps/meteor/playwright.config.ts` — `video: 'retain-on-failure'` off-CI,
  output `tests/e2e/.playwright`, launch args already pass `--use-fake-*-for-media-stream` and grant
  the microphone (so voice calls work headless).
- Admin creds and `DEFAULT_USER_CREDENTIALS` (`password: 'password'`): `tests/e2e/config/constants.ts`.
  `TEST_MODE=api` on the server seeds that admin; `rc-api.sh` uses it.
- App install/uninstall helpers: `tests/e2e/utils/apps.ts`.
- `globalSetup` (`tests/e2e/config/global-setup.ts`) injects `user1`…`userE2EE` straight into Mongo,
  so a fresh database works — but it only adds a login token to the admin, it does not create it.
- Meteor in dev puts a proxy on the port you asked for and runs the inner app server on a private
  port, which it exports as `PORT`. The browser-facing port lives in `ROOT_URL`; `find-server.sh`
  reads it from there.
- Meteor loads each workspace package through its `main`, which points at `dist`. An edit to
  `packages/*/src` is invisible to the app until that package is built. `preflight.sh` flags a
  changed source that is newer than its `dist`.
