---
name: record-ui-video
description: Record a screen video of a Rocket.Chat UI flow (a demo, a repro, a walkthrough) by driving the real app with Playwright. Where the host allows it, ffmpeg captures a virtual display at a constant frame rate with sound; elsewhere Playwright's own recorder stands in. Use when the user asks to record, film, capture, or screen-record a scenario in apps/meteor.
---

# Record a UI video

Drive the real `apps/meteor` app with a throwaway Playwright spec and keep the screen. The spec
reuses the e2e fixtures, so you never log in through a form or wire up auth by hand.

## What you need first

A Rocket.Chat dev server must already run. This skill records against a server; it never starts,
stops or configures one. `preflight.sh` reports the server it found, or reports that there is none.
When there is none, say so and stop.

Nothing else is a hard requirement. Every host can record; the host only decides how well. See
"[The two strategies](#the-two-strategies)".

## The two strategies

`record.sh` picks one and prints which. `preflight.sh` says the same thing before you write a line
of scenario.

| | `native` | `playwright` |
| --- | --- | --- |
| How | ffmpeg grabs a headed browser on a virtual display | Playwright's own recorder |
| Frame rate | constant, 60 fps by default | about 25 fps, a frame only when the page changes |
| Idle beats | recorded as they play | dropped, so a pause reads as a jump |
| Audio | the ringtones and call audio the app plays | none; the recorder writes no audio track |
| Needs | a platform file with a display and a grab | nothing beyond the browser |

**Prefer `native`.** It is what makes a demo look driven by a person rather than assembled from
screenshots. The fallback exists so a host without a virtual display still gets a usable video, not
because the two are equal. When the preflight reports the fallback, say so and say what it costs
before you record — the user may rather install the missing tools, or record elsewhere.

Force one with `record.sh --strategy native|playwright`; `auto` is the default and picks native
whenever the host can run it.

### How `native` records

- `Xvfb` gives the run a display of its own, so no desktop window can cover the browser.
- Chromium runs **headed** on that display. A real window means a real compositor.
- `ffmpeg -f x11grab` grabs the page rectangle at a fixed rate, so motion is smooth and even.
- The browser plays into a PulseAudio **null sink** of its own, and ffmpeg records that sink's
  monitor. The video carries the ringtones and call audio, and the user hears nothing.

Today one platform file implements this: `linux-x11`. A Wayland desktop is fine, because the
recording never touches it — it brings its own X display. See
"[Adding a platform](#adding-a-platform)".

### How `playwright` records

Chromium runs headless and records itself, so there is no display to start, no window to place and
no crop to calibrate. `record.sh` collects the `.webm` Playwright wrote and encodes the same MP4
from it. Without ffmpeg on the host it hands over that `.webm` and cuts no check frames.

The scenario code never changes between the two. Only the `test.use` block does, and the template
already switches it on `RECORD_STRATEGY`.

## Scripts

Four scripts in `scripts/` next to this file replace the environment reads. Run them instead of
probing `ps`, `ss`, `/proc`, or the browser cache yourself. Each one accepts `--help`. They call the
platform layer for everything that differs between operating systems, and name none of it
themselves.

| Script | What it answers |
| --- | --- |
| `preflight.sh` | Is everything in place to record? What is missing, and who fixes it? |
| `find-server.sh` | Which dev server is running, on which port, against which database? |
| `record.sh` | Run the spec, capture it (either strategy), encode an MP4, extract frames to verify. |
| `rc-api.sh` | One-line authenticated admin REST call, for setup and cleanup checks. |

`record.sh` calls `calibrate.js` itself; see "The window has no manager".

`platform.sh` and `platform/` are not scripts you run. `platform.sh` picks the file under
`platform/` that fits the host and sources it; the four scripts then call its functions.

The scripts print absolute paths, because `cd apps/meteor` in one Bash call persists into the next
one and breaks a relative path.

## Steps

### 1. Run the preflight

```bash
.claude/skills/record-ui-video/scripts/preflight.sh
```

It checks the platform, the workspace, `node_modules`, stale package builds, the chromium browser,
the capture strategy and what it needs, the audio, and the dev server. It exits 0 when ready or 1
with a list of fixes split into three groups: the ones it can run, the ones only the user can do,
and the optional ones.

An **optional** fix never blocks a recording. It is what the `native` strategy would need on a host
that is about to fall back to `playwright`. Report it, with what the fallback costs, and let the
user decide.

If it reports missing prerequisites, ask the user which way they want to go before you touch
anything. Use `AskUserQuestion` with the script's own two blocking groups as the options:

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
- The `test.use` block, and **both** of its branches. `record.sh` sets `RECORD_STRATEGY`, and the
  spec picks the settings that fit. Edit the scenario, not this block.
  - Native branch:
    - `headless: false` — a real window for ffmpeg to grab. `chromium-headless-shell` cannot stand
      in here: it has no window.
    - `viewport: null` — the page takes the window's own size. An emulated viewport makes Chromium
      scale the page into the window, and the capture resamples every glyph.
    - `video: 'off'` — Playwright's recorder would only duplicate the capture, slowly.
    - `--window-position=0,0` puts the window where the calibrated crop expects it, and
      `--window-size=${windowSize}` is the value `record.sh` measured and passed in
      `RECORD_WINDOW_SIZE`.
  - Playwright branch:
    - `headless: true` — the fallback host may have no display at all.
    - `channel: 'chromium-headless-shell'` — the shell draws no browser chrome, so its surface is
      the viewport. The full chromium of `playwright.config.ts` draws chrome even headless, its
      surface comes out 85px short, and Playwright pads the video with a grey band that eats the
      composer. This is the one line that decides whether the fallback video is usable.
    - `viewport` and `video.size` both set to `RECORD_VIEWPORT`. Set `size`, always: Playwright
      otherwise scales the video down to fit into 800x800.
  - `launchOptions.args` — this array **replaces** the one in `playwright.config.ts`, so both
    branches repeat the fake-media args. Without them a call cannot get a microphone, and
    `--autoplay-policy=no-user-gesture-required` is what lets a ringtone play at all.
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

On a host with no virtual display it runs the spec headless instead and keeps Playwright's own
recording; steps 2 to 5 above do not happen.

Useful options: `--strategy native|playwright` to force one, `--name` for the output basename,
`--out-dir` for the destination, `--fps N` (60 by default, native only), `--no-audio`, `--no-trim`,
`--keep-raw` for the lossless capture, `--frame-every N` for the check-frame interval,
`--recalibrate`, and `--port` / `--mongo-url` to override discovery.

The run takes ~40 s. `record.sh` exits with the spec's own exit code and warns you when the video
records a failed run.

Read the summary it prints:

- The `capture:` line names the strategy. Say which one produced the video when you hand it over.
- `avg_frame_rate` should equal `--fps` on `native`. A `capture:` line naming dropped frames means
  the machine could not keep up; re-run with `--fps 30`. On `playwright` the rate is whatever the
  page changes gave, and a lower number is not a fault.
- `audio: peak <n> dB` says sound was captured. `audio: silent` means the scenario played nothing —
  fine for a silent flow, a bug if you expected a ringtone. On `playwright` there is never audio.

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

Only the `native` strategy records audio. Playwright's recorder writes no audio track at all, so a
flow whose point is a ringtone cannot be recorded on the fallback — say so rather than hand over a
silent video of it.

On `native`, the browser gets a PulseAudio null sink of its own (`PULSE_SINK` in its environment) and `parec`
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

`page.mouse` moves a synthetic cursor **inside** the browser, and neither strategy captures a real
one: `native` grabs the display with `-draw_mouse 0`, and Playwright's recorder records the page.
So the only cursor in either video is the dot that `showPointer` draws. Keep that helper.

A raw `locator.click()` teleports the synthetic cursor, and the dot jumps with it.
`glideClick(page, locator, steps)` interpolates the move, so the dot travels. At 60 fps the glide is
what makes the video look driven by a person. Raise `steps` for a slower one.

## The window has no manager

This is `native` only; Playwright's recorder records the page and never sees a window.

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

## Adding a platform

Everything that differs between operating systems lives in one file under `scripts/platform/`.
`platform.sh` holds the contract, tries each id in `PLATFORM_CANDIDATES`, and sources the first file
whose `platform_detect` says it fits the host. Nothing outside `platform/` names an operating
system, a display server or a capture device.

Two files exist. `linux-x11` implements everything and declares `PLATFORM_CAPTURE='native'`.
`portable` fits every host, implements host facts only, and declares `PLATFORM_CAPTURE='none'`,
which is what sends `record.sh` to Playwright's recorder. `portable` is last in the list, so a new
file wins over it.

To add native capture for a system: copy `platform/linux-x11.sh`, implement the same functions, and
add its id to `PLATFORM_CANDIDATES` **before** `portable`. The contract has two halves.

Host facts, which every platform file implements:

| Function | What it owns |
| --- | --- |
| `platform_detect` | Whether this file fits the host; the reason on stderr when it does not. |
| `platform_list_server_processes` | One `port\|mongo_url\|meteor_pwd\|pid` line per dev server process. |

Native capture, which a file implements only when the host can run it:

| Function | What it owns |
| --- | --- |
| `platform_check_capture` | Preflight rows for the display and the grab tools. |
| `platform_check_audio` | Preflight rows for the audio tools; the feature is optional. |
| `platform_display_start` / `_stop` | A display of a given size that the browser and the grab both see. |
| `platform_capture_input` | The ffmpeg input args for one rectangle of it, at a frame rate. |
| `platform_screen_input` | The ffmpeg input args for one whole-screen frame, for the calibration. |
| `platform_audio_open` / `_start` / `_close` | Route what the browser plays into a stream ffmpeg can read. |

A file that cannot capture still defines all six, to report `ABSENT` and to fail with a clear reason
when someone forces `--strategy native`. See `platform/portable.sh`.

A preflight row is `STATUS|label|info|fix`. `OK` passes, `MISSING` fails the preflight, and `ABSENT`
reports an optional feature as unavailable without failing. When the run has already fallen back to
Playwright, `preflight.sh` reads a `MISSING` capture row as `ABSENT` and files its fix under
"optional".

Set `RECORD_PLATFORM=<id>` to force one candidate. Use it to exercise the fallback on a host that
would otherwise pick a native one: `RECORD_PLATFORM=portable preflight.sh`.

Two things stay outside the platform layer, because they do not vary: the encoding and trimming that
`record.sh` does with plain ffmpeg filters, and the calibration algorithm in `calibrate.js`, which
takes the grab args from `platform_screen_input` rather than building them.

## Trimming

This is `native` only. The capture starts before Chromium maps its window and runs on after it
closes; both ends are the bare X root window, which is pure black. `record.sh` finds those two black
stretches with `blackdetect` and cuts them. Nothing the app draws is pure black, not even the dark
theme, so the cut is safe. Pass `--no-trim` to keep them.

Playwright's recorder starts with the page and stops with it, so there is nothing to cut and
`record.sh` does not try.

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
- `yarn playwright install chromium` fetches both `chromium-*` and `chromium_headless_shell-*`.
  `native` drives the first, the `playwright` fallback drives the second, and `preflight.sh` checks
  whichever one the chosen strategy needs.
- `record.sh` passes `--output <temp dir>` to the fallback run, so its webm never lands in the
  shared `tests/e2e/.playwright`.
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
