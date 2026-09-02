# Write the spec

Read this when you write or repair the throwaway spec: what the template block does, how the
pointer moves, which locators break a run, and how to clear the state the screen shows.

## Keep these parts of the template unchanged

They are what make the video work.

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

## The pointer

`page.mouse` moves a synthetic cursor **inside** the browser, and neither strategy captures a real
one: `native` grabs the display with `-draw_mouse 0`, and Playwright's recorder records the page.
So the only cursor in either video is the dot that `showPointer` draws. Keep that helper.

A raw `locator.click()` teleports the synthetic cursor, and the dot jumps with it.
`glideClick(page, locator, steps)` interpolates the move, so the dot travels. At 60 fps the glide is
what makes the video look driven by a person. Raise `steps` for a slower one.

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
~/.claude/skills/record-ui-video/scripts/rc-api.sh POST /api/v1/rooms.cleanHistory \
  '{"roomId":"<id>","oldest":"2000-01-01T00:00:00.000Z","latest":"2100-01-01T00:00:00.000Z"}'
```

Tell the user what the screen will show if you do not clear it.
