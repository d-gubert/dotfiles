---
name: record-ui-video
description: Record a screen video (a screencast, a demo, a repro, a walkthrough) of a Rocket.Chat UI flow by driving the real app with Playwright. Use when the user asks to record, film, capture, screen-record or make a video or a demo of a scenario in apps/meteor.
---

# Record a UI video

Drive the real `apps/meteor` app with a throwaway Playwright spec and keep the screen. The spec
reuses the e2e fixtures, so you never log in through a form or wire up auth by hand.

## What you need first

A Rocket.Chat dev server must already run. This skill records against a server; it never starts,
stops or configures one. `preflight.sh` reports the server it found, or reports that there is none.
When there is none, say so and stop.

Nothing else is a hard requirement. Every host can record; the host only decides how well.

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
before you record — the user may rather install the missing tools, or record elsewhere. A flow whose
point is a ringtone cannot be recorded on the fallback at all.

Force one with `record.sh --strategy native|playwright`; `auto` is the default and picks native
whenever the host can run it.

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

`record.sh` calls `calibrate.js` itself; see
[reference/capture-internals.md](reference/capture-internals.md).

`platform.sh` and `platform/` are not scripts you run. `platform.sh` picks the file under
`platform/` that fits the host and sources it; the four scripts then call its functions.

The scripts print absolute paths, because `cd apps/meteor` in one Bash call persists into the next
one and breaks a relative path.

## Steps

### 1. Run the preflight

```bash
~/.claude/skills/record-ui-video/scripts/preflight.sh
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
and edit the scenario. It is a spec, not a suite: assertions only gate the recording.

Edit the scenario and nothing else. Keep `RECORD_VIEWPORT`, the whole `test.use` block with **both**
of its branches, `storageState`, the `api` fixture, and the `showPointer` / `beat` / `glideClick`
helpers as the template has them. Every one of them is load-bearing.

**Read [reference/write-the-spec.md](reference/write-the-spec.md) before you edit.** It says what
each of those parts does, how the pointer moves, which locators break a run, and how to clear the
state the screen shows.

### 3. Record one screen, not two

Most flows need one actor's screen. Put the other side online by API
(`users.setStatus`) instead of opening a second browser.

### 4. Run it

```bash
~/.claude/skills/record-ui-video/scripts/record.sh tests/e2e/demos/<name>-demo.spec.ts
```

It finds the running dev server, starts the display, calibrates the window (once per Chromium
build), captures the run, trims the black head and tail, encodes the MP4 and extracts check frames.
It prints the path of every output plus the log.

On a host with no virtual display it runs the spec headless instead and keeps Playwright's own
recording; the display, the calibration and the trim do not happen.

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

When the video comes out wrong, read
[reference/capture-internals.md](reference/capture-internals.md).

### 5. Verify the frames before you hand the video over

`record.sh` prints a frames directory. `Read` a few of those PNGs. Confirm the flow, and confirm the
frame holds the page alone, with no browser chrome and no black band.

### 6. Clean up

Keep the spec unless the user asks you to delete it — they may want another take. Confirm no app
you installed is left behind:

```bash
~/.claude/skills/record-ui-video/scripts/rc-api.sh GET /api/apps/installed
```

`record.sh` kills its own display, sink and capture on the way out, even when the spec fails.

## Read more

Each file below loads on demand. Read one only when its case applies.

| File | Read it when |
| --- | --- |
| [reference/write-the-spec.md](reference/write-the-spec.md) | You write or repair the spec: the template block, the pointer, locator hygiene, page objects, leftover state. |
| [reference/capture-internals.md](reference/capture-internals.md) | A video comes out wrong: a low frame rate, silent audio, bad framing, a surviving black band. |
| [reference/fixture-apps.md](reference/fixture-apps.md) | The recording must show an app that says or does something specific. |
| [reference/platform-layer.md](reference/platform-layer.md) | You add native capture for another operating system, or you explain why a host falls back. |
| [reference/facts.md](reference/facts.md) | A run fails for a reason the steps do not cover. |
