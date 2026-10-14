# Capture internals

Read this when a video comes out wrong: the frame rate drops, the audio is silent, the framing is
off, or a black band survives the trim.

## How `native` records

- `Xvfb` gives the run a display of its own, so no desktop window can cover the browser.
- Chromium runs **headed** on that display. A real window means a real compositor.
- `ffmpeg -f x11grab` grabs the page rectangle at a fixed rate, so motion is smooth and even.
- The browser plays into a PulseAudio **null sink** of its own, and ffmpeg records that sink's
  monitor. The video carries the ringtones and call audio, and the user hears nothing.

Today one platform file implements this: `linux-x11`. A Wayland desktop is fine, because the
recording never touches it — it brings its own X display. See
[platform-layer.md](platform-layer.md).

## How `screencast` records

Chromium runs headless, so there is no display to start, no window to place and no crop to
calibrate. The spec's `beforeEach` loads `scripts/screencast.js` and starts a CDP screencast
(`Page.startScreencast`, JPEG at quality 90). The compositor sends a frame each time it draws a
change, up to 60 per second. `screencast.js` acks each frame at once and writes it to disk with
its timestamp.

The `afterEach` stops it and writes `frames.ffconcat`: each frame lasts until the next one, so a
still beat stays in the video as one held frame. `record.sh` then encodes that list to a constant
`--fps` rate. The list has three quirks of the concat demuxer, documented in `screencast.js`; the
one to know is the 1 ms time base, which needs `-safe 0`.

`screencast.js` also cuts the blank `about:blank` frames before the first navigation, so the video
starts on the app, not on a white screen.

## How `playwright` records

Chromium runs headless and records itself. It reads the same screencast as `screencast`, then
resamples it onto a fixed 25 fps grid and encodes realtime VP8 at 1 Mbit/s (`videoRecorder.js` in
`playwright-core`). `record.sh` collects that `.webm` and encodes the same MP4 from it. Without
ffmpeg on the host it hands over the `.webm` and cuts no check frames.

The scenario code never changes between the three. Only the `test.use` block and the screencast
hooks do, and the template already switches them on `RECORD_STRATEGY`.

## Audio

Only the `native` strategy records audio. A CDP screencast carries pictures only, so neither
fallback has an audio track. A flow whose point is a ringtone cannot be recorded on a fallback — say
so rather than hand over a silent video of it.

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

## The window has no manager

This is `native` only; the headless strategies record the page and never see a window.

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

This is `native` only. The capture starts before Chromium maps its window and runs on after it
closes; both ends are the bare X root window, which is pure black. `record.sh` finds those two black
stretches with `blackdetect` and cuts them. Nothing the app draws is pure black, not even the dark
theme, so the cut is safe. Pass `--no-trim` to keep them.

The headless strategies start with the page and stop with it, so there is nothing to cut and
`record.sh` does not try.
