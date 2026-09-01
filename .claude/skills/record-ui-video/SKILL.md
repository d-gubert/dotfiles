---
name: record-ui-video
description: Record a screen video of a Rocket.Chat UI flow (a demo, a repro, a walkthrough) by driving the real app with Playwright on a virtual display and capturing it with ffmpeg, sound included. Use when the user asks to record, film, capture, or screen-record a scenario in apps/meteor.
---

# Record a UI video

Drive the real `apps/meteor` app with a throwaway Playwright spec, run the browser headed on a
virtual X display, and let ffmpeg record that display at a constant 60 fps with the audio the app
plays. The spec reuses the e2e fixtures, so you never log in through a form or wire up auth by hand.

## What you need first

A Rocket.Chat dev server must already run. This skill records against a server; it never starts,
stops or configures one. `preflight.sh` reports the server it found, or reports that there is none.
When there is none, say so and stop.

## How it records

Playwright has a video recorder of its own, and this skill does not use it. That recorder captures a
frame only when the page compositor changes, caps around 25 fps, drops frames during idle beats and
records no audio.

Instead:

- `Xvfb` gives the run a display of its own, so no desktop window can cover the browser.
- Chromium runs **headed** on that display. A real window means a real compositor.
- `ffmpeg -f x11grab` grabs the page rectangle at a fixed rate, so motion is smooth and even.
- The browser plays into a PulseAudio **null sink** of its own, and ffmpeg records that sink's
  monitor. The video carries the ringtones and call audio, and the user hears nothing.

## Scripts

Four scripts in `scripts/` next to this file replace the environment reads. Run them instead of
probing `ps`, `ss`, `/proc`, or the browser cache yourself. Each one accepts `--help`.

| Script | What it answers |
| --- | --- |
| `preflight.sh` | Is everything in place to record? What is missing, and who fixes it? |
| `find-server.sh` | Which dev server is running, on which port, against which database? |
| `record.sh` | Run the spec, capture it, trim it, encode an MP4, extract frames to verify. |
| `rc-api.sh` | One-line authenticated admin REST call, for setup and cleanup checks. |

`record.sh` calls `calibrate.js` itself; see "The window has no manager".

The scripts print absolute paths, because `cd apps/meteor` in one Bash call persists into the next
one and breaks a relative path.

## Steps

### 1. Run the preflight

```bash
.claude/skills/record-ui-video/scripts/preflight.sh
```

It checks the workspace, `node_modules`, stale package builds, the chromium browser, `Xvfb`, an
`ffmpeg` with `x11grab`, the audio server, and the dev server. It exits 0 when ready or 1
with a list of fixes split into two groups: the ones it can run and the ones only the user can do.

If it reports missing prerequisites, ask the user which way they want to go before you touch
anything. Use `AskUserQuestion` with the script's own two groups as the options:

- **Let the skill install them** — you run `preflight.sh --install`. It installs dependencies,
  builds stale packages, and downloads the browser, then re-checks.
- **The user installs them** — you print the commands and wait.

Two fixes are slow (`yarn build`, a browser download), so never run `--install` unasked. `Xvfb`,
`ffmpeg` and the audio tools need `sudo`, so they are always the user's to install.

A running dev server is a prerequisite of this skill, not a step in it. Never start one. If none is
running, report that and stop; the user decides how their server runs.

One running server is used as it is. When several run, the scripts prefer the one that runs from
the current checkout; if that is still ambiguous they list the servers and stop, and you pass
`--port <port>` to choose.

> Warning: a server serves the code of *its own* directory, not the code you are looking at.
> `preflight.sh` and `find-server.sh` both report the directory, branch and version behind each
> port. Check them before you record.

### 2. Write a throwaway spec

Copy `template.spec.ts` (next to this file) into `apps/meteor/tests/e2e/demos/<name>-demo.spec.ts`
and edit the scenario. It is a spec, not a suite: assertions only gate the recording. Keep these
parts unchanged — they are what make the video work:

- `const RECORD_VIEWPORT = '1280x720'` — the size of the page in the video. `record.sh` reads this
  line out of the spec to size the display and to calibrate the crop, so keep the name and the
  `WIDTHxHEIGHT` shape.
- The `test.use` block:
  - `headless: false` — a real window for ffmpeg to grab. **`chromium-headless-shell` cannot be
    used any more**: it has no window.
  - `viewport: null` — the page takes the window's own size. An emulated viewport makes Chromium
    scale the page into the window, and the capture resamples every glyph.
  - `video: 'off'` — Playwright's recorder would only duplicate the capture, slowly.
  - `launchOptions.args` — this array **replaces** the one in `playwright.config.ts`, so it repeats
    the fake-media args. Without them a call cannot get a microphone. `--window-position=0,0` puts
    the window where the calibrated crop expects it, and `--autoplay-policy=no-user-gesture-required`
    lets ringtones play, which is what puts sound on the tape.
  - `--window-size=${windowSize}` — `record.sh` passes the measured value in `RECORD_WINDOW_SIZE`.
- `storageState: Users.user1.state` — logs the page in as `user1` with no login screen. Login
  tokens are deterministic: `base64(sha256(username))`, pre-seeded in the DB. Pick any of
  `Users.user1`, `Users.user2`, … from `tests/e2e/fixtures/userStates.ts`.
- The `api` fixture (from `tests/e2e/utils/test.ts`) is the **admin** REST context. Use it for
  setup: `api.post('/users.setStatus', { status: 'online', username })`, settings, app modes.
- `showPointer(page)`, `beat(page)` and `glideClick(page, locator)` — a visible cursor dot,
  deliberate pauses and smooth pointer motion. See "The pointer" below.

### 3. Record one screen, not two

Most flows need one actor's screen. Put the other side online by API
(`users.setStatus`) instead of opening a second browser.

### 4. Run it

```bash
.claude/skills/record-ui-video/scripts/record.sh tests/e2e/demos/<name>-demo.spec.ts
```

It finds the running dev server, starts the display, calibrates the window (once per Chromium
build), captures the run, trims the black head and tail, encodes the MP4 and extracts check frames.
It prints the path of every output plus the log.

Useful options: `--name` for the output basename, `--out-dir` for the destination, `--fps N` (60 by
default), `--no-audio`, `--no-trim`, `--keep-raw` for the lossless capture, `--frame-every N` for
the check-frame interval, `--recalibrate`, and `--port` / `--mongo-url` to override discovery.

The run takes ~40 s. `record.sh` exits with the spec's own exit code and warns you when the video
records a failed run.

Read the summary it prints:

- `avg_frame_rate` should equal `--fps`. A `capture:` line naming dropped frames means the machine
  could not keep up; re-run with `--fps 30`.
- `audio: peak <n> dB` says sound was captured. `audio: silent` means the scenario played nothing —
  fine for a silent flow, a bug if you expected a ringtone.

### 5. Verify the frames before you hand the video over

`record.sh` prints a frames directory. `Read` a few of those PNGs. Confirm the flow, and confirm the
frame holds the page alone, with no browser chrome and no black band.

### 6. Clean up

Keep the spec unless the user asks you to delete it — they may want another take. Confirm no app
you installed is left behind:

```bash
.claude/skills/record-ui-video/scripts/rc-api.sh GET /api/apps/installed
```

`record.sh` kills its own display, sink and capture on the way out, even when the spec fails.

## Audio

The browser gets a PulseAudio null sink of its own (`PULSE_SINK` in its environment) and `parec`
reads that sink's monitor into ffmpeg. So the recording holds what the app played and nothing else
the machine was playing, and the sound never reaches the speakers.

Two things make or break it:

- `--autoplay-policy=no-user-gesture-required` in the spec's launch args. Without it Chromium blocks
  the first sound, because a Playwright click is not a user gesture in the sense the policy means.
- `parec --latency-msec=50` in `record.sh`. `parec` defaults to a buffer of about two seconds; the
  audio then reaches ffmpeg in late bursts, ffmpeg waits for the lagging stream, and x11grab drops
  three video frames out of four. This is the one setting that decides whether the capture runs at
  60 fps or at 14. Do not remove it.

Pass `--no-audio` for a flow with no sound; the video is the same, only smaller.

## The pointer

`page.mouse` moves a synthetic cursor **inside** the browser. The X pointer never moves, so the
capture runs with `-draw_mouse 0` and the only cursor in the video is the dot that `showPointer`
draws. Keep that helper.

A raw `locator.click()` teleports the synthetic cursor, and the dot jumps with it.
`glideClick(page, locator, steps)` interpolates the move, so the dot travels. At 60 fps the glide is
what makes the video look driven by a person. Raise `steps` for a slower one.

## The window has no manager

Nothing on the virtual display resizes or decorates the browser: Chromium draws its own tab strip
and omnibox and keeps the size it was asked for. Two numbers follow from that, and both belong to
the Chromium build rather than to the scenario:

1. the `--window-size` that leaves a content area of exactly `RECORD_VIEWPORT`
2. where that content area sits on the screen, which is the crop rectangle for ffmpeg

`calibrate.js` measures both: it launches, reads `innerWidth`/`innerHeight`, corrects the request,
launches again, then paints one solid magenta page. It grabs a frame of that page with ffmpeg and
reads the rectangle out of the raw pixels — measured, not guessed. The result is cached in
`~/.cache/record-ui-video/geometry-<playwright version>-<size>.env`. Pass `--recalibrate` after a
Playwright upgrade if the framing ever looks wrong.

This is also why the spec must keep `--window-position=0,0`.

## Trimming

The capture starts before Chromium maps its window and runs on after it closes; both ends are the
bare X root window, which is pure black. `record.sh` finds those two black stretches with
`blackdetect` and cuts them. Nothing the app draws is pure black, not even the dark theme, so the
cut is safe. Pass `--no-trim` to keep them.

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
`content.messageById(id)`, `content.lastUserMessage`, `btnContextualbarClose`, and
`voiceCalls.widget` / `voiceCalls.roomSection` (see `fragments/voice-calls.ts`:
`controls.call/accept/reject/hangup/cancel`, `initiateCall()`, `acceptCall()`). Reuse them instead
of raw locators.

## Leftover state shows up on screen

The database keeps what earlier runs wrote. A DM shows every prevented-call card from every take,
and a call history shows every old row. The video still reads, but a clean screen reads better.
Clear the state before the take with `rc-api.sh`, for example:

```bash
scripts/rc-api.sh POST /api/v1/rooms.cleanHistory \
  '{"roomId":"<id>","oldest":"2000-01-01T00:00:00.000Z","latest":"2100-01-01T00:00:00.000Z"}'
```

Tell the user what the screen will show if you do not clear it.

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

- Playwright config: `apps/meteor/playwright.config.ts` — `channel: 'chromium'`, `headless: true`,
  output `tests/e2e/.playwright`, launch args pass `--use-gl=egl --use-fake-*-for-media-stream` and
  grant the microphone. The recording spec overrides the first two and repeats the args.
- A headed Chromium renders fine on `Xvfb` with `--use-gl=egl`; it falls back to software rendering.
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
- An ffmpeg from Homebrew has `x11grab` but no `pulse` input device, and its bundled `alsa-lib`
  cannot load the system ALSA-to-PulseAudio plugin. That is why the audio arrives through `parec`
  and a fifo instead of `-f pulse`.
