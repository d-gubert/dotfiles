# Facts that save a re-research

Read this when a run fails for a reason the steps do not cover.

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
