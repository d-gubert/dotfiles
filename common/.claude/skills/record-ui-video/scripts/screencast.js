/**
 * The recorder of the `screencast` strategy: a CDP screencast that keeps the time of every frame.
 *
 * Playwright's own recorder reads the same screencast, but it resamples the frames onto a fixed
 * 25 fps grid and encodes them as realtime VP8 at 1 Mbit/s. This one writes each JPEG to disk as
 * it arrives, with the time the compositor swapped it, and leaves the encode to `record.sh`. The
 * video then moves when the page moved, at the rate the compositor drew, up to 60 fps.
 *
 * The compositor sends a frame only when the page changes. A still page sends none, so each frame
 * lasts until the next one: `frames.ffconcat` holds those durations, and ffmpeg turns that into a
 * constant frame rate.
 *
 * The spec loads it through RECORD_SCREENCAST_JS, which `record.sh` sets; see template.spec.ts.
 *
 *   const stop = await startScreencast(page, dir, { width, height });
 *   … the scenario …
 *   const { frames, seconds } = await stop();
 */
'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Start to record `page` into `dir`. Resolves to a function that stops the recording, writes
 * `frames.ffconcat`, and resolves to the frame count and the length in seconds.
 */
async function startScreencast(page, dir, { width, height, quality = 90 } = {}) {
	fs.mkdirSync(dir, { recursive: true });
	const session = await page.context().newCDPSession(page);
	const frames = [];
	const writes = [];
	let stopped = false;

	session.on('Page.screencastFrame', ({ data, metadata, sessionId }) => {
		// Ack first: the browser sends the next frame only after the ack, so a late ack costs frames.
		session.send('Page.screencastFrameAck', { sessionId }).catch(() => undefined);
		if (stopped) {
			return;
		}
		const file = `f_${String(frames.length).padStart(6, '0')}.jpg`;
		frames.push({ file, time: metadata.timestamp, blank: page.url() === 'about:blank' });
		writes.push(fs.promises.writeFile(path.join(dir, file), data, 'base64'));
	});

	await session.send('Page.startScreencast', {
		format: 'jpeg',
		quality,
		maxWidth: width,
		maxHeight: height,
		everyNthFrame: 1,
	});

	return async function stop() {
		// metadata.timestamp is wall-clock seconds, so the last frame lasts until now.
		const end = Date.now() / 1000;
		stopped = true;
		await session.send('Page.stopScreencast').catch(() => undefined);
		await Promise.all(writes);
		await session.detach().catch(() => undefined);

		// The page is blank until the spec navigates. Cut those frames, so the video does not open
		// on a white screen that lasts as long as the first page load. A spec that never navigates
		// (`page.setContent`) stays on about:blank, so keep everything then.
		const firstPage = frames.findIndex((frame) => !frame.blank);
		if (firstPage > 0) {
			frames.splice(0, firstPage);
		}

		// Three quirks of the concat demuxer shape this list:
		//  - Each JPEG opens as a one-frame image2 input with a 1/25 s time base, which rounds every
		//    duration to 40 ms. `option framerate 1000` makes that 1 ms. It needs `-safe 0`.
		//  - It ignores the duration of the last entry, so the last file comes again at the end.
		//  - It gives that closing entry the duration of the entry before it, so a 1 ms entry goes
		//    in between. Without it, a final still beat would play twice.
		const lines = ['ffconcat version 1.0'];
		const entry = (file, seconds) => {
			lines.push(`file ${file}`, 'option framerate 1000');
			if (seconds !== undefined) {
				lines.push(`duration ${Math.max(seconds, 0.001).toFixed(3)}`);
			}
		};
		frames.forEach((frame, i) => entry(frame.file, (i + 1 < frames.length ? frames[i + 1].time : end) - frame.time));
		if (frames.length > 0) {
			const last = frames[frames.length - 1].file;
			entry(last, 0.001);
			entry(last);
		}
		fs.writeFileSync(path.join(dir, 'frames.ffconcat'), `${lines.join('\n')}\n`);

		return { frames: frames.length, seconds: frames.length > 0 ? end - frames[0].time : 0 };
	};
}

module.exports = { startScreencast };
