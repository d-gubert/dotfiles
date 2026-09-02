# The platform layer

Read this to add native capture for another operating system, or to understand why a host falls
back to Playwright's recorder.

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
