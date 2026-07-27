// Higher-fps recording of the #41019 growth column via CDP screencast.
//
// Playwright's built-in recordVideo is locked to ~25fps with no fps option, so
// this script bypasses it: it drives the Chrome DevTools Protocol screencast
// (Page.startScreencast), which emits one frame per repaint (up to the display
// refresh, ~60fps). Each frame carries a timestamp; we write frames to disk,
// then let ffmpeg resample the real-time-paced sequence to a constant FPS and
// crop it to the #41019 column — same SCALE / dark-mode / crop behavior as
// record-growth-41019.cjs.
//
// Usage: node record-growth-41019-cdp.cjs
//   env: FPS=60       output frame rate (default 60)
//        STEP_MS=400  ms between animation steps (lower = snappier)
//        SCALE=2      render zoom → resolution multiplier
//        KEEP_RAW=1   keep the extracted frame directory
// Output: growth-41019-column-hifps.mp4
const { execFileSync } = require('child_process');
const { existsSync, readdirSync, rmSync, mkdirSync, writeFileSync } = require('fs');
const path = require('path');

const { chromium } = require('playwright');

// The repo's Playwright and the npx-installed browser can disagree on the
// chromium build number, so find whatever chrome is actually in the cache.
function findChrome() {
	try {
		const p = chromium.executablePath();
		if (existsSync(p)) return p; // versions match — use the default
	} catch {
		// fall through to the cache scan
	}
	const cache = path.join(process.env.HOME, '.cache', 'ms-playwright');
	for (const d of readdirSync(cache).filter((n) => n.startsWith('chromium-'))) {
		for (const sub of ['chrome-linux64/chrome', 'chrome-linux/chrome']) {
			const c = path.join(cache, d, sub);
			if (existsSync(c)) return c;
		}
	}
	return undefined; // let Playwright try its default and error clearly
}

const VW = 1280;
const VH = 800;
const SCALE = parseFloat(process.env.SCALE || '2');
const FPS = parseInt(process.env.FPS || '60', 10);
const STEP_MS = parseInt(process.env.STEP_MS || '1000', 10);
const PAD = 14; // breathing room around the column in the crop
const HOLD_S = 1.0; // seconds to hold the final frame

(async () => {
	const file = `file://${path.resolve(__dirname, 'pr-41019-growth.html')}`;
	const outDir = path.resolve(__dirname);
	const framesDir = path.join(outDir, '.screencast-frames');
	const finalOut = path.join(outDir, 'growth-41019-column-hifps.mp4');

	rmSync(framesDir, { recursive: true, force: true });
	mkdirSync(framesDir, { recursive: true });

	const browser = await chromium.launch({ executablePath: findChrome() });
	const context = await browser.newContext({
		colorScheme: 'dark',
		viewport: { width: VW * SCALE, height: VH * SCALE },
		reducedMotion: 'no-preference', // let the FLIP / chip transitions play
	});
	const page = await context.newPage();
	await page.goto(file, { waitUntil: 'networkidle' });

	const lane = page.locator('.lane.is-source'); // the #41019 column
	await lane.waitFor();

	// Zoom the whole page so it fills the enlarged viewport at SCALE× the pixels.
	await page.evaluate((s) => {
		document.documentElement.style.zoom = String(s);
	}, SCALE);

	// Pin the animation stage near the top of the viewport.
	await page.locator('#anim-stage').evaluate((el) => {
		el.scrollIntoView({ block: 'start' });
		window.scrollBy(0, -32);
	});
	await page.waitForTimeout(200);

	// Track the column's tallest bounding box for the crop.
	const boxOf = () =>
		lane.evaluate((el) => {
			const r = el.getBoundingClientRect();
			return { left: r.left, top: r.top, width: r.width, bottom: r.bottom };
		});
	const box = await boxOf();
	const acc = { left: box.left, top: box.top, width: box.width, bottom: box.bottom };
	const track = (b) => {
		acc.left = Math.min(acc.left, b.left);
		acc.top = Math.min(acc.top, b.top);
		acc.width = Math.max(acc.width, b.width);
		acc.bottom = Math.max(acc.bottom, b.bottom);
	};

	// Start the CDP screencast. Each frame is written to disk immediately (keeps
	// memory flat) and its timestamp recorded for real-time-accurate pacing.
	const client = await page.context().newCDPSession(page);
	const frames = []; // { file, ts }
	let n = 0;
	client.on('Page.screencastFrame', async (evt) => {
		const idx = n++;
		const f = path.join(framesDir, `f${String(idx).padStart(6, '0')}.jpg`);
		writeFileSync(f, Buffer.from(evt.data, 'base64'));
		frames.push({ file: f, ts: evt.metadata.timestamp });
		try {
			await client.send('Page.screencastFrameAck', { sessionId: evt.sessionId });
		} catch {
			// session may be closing — ignore
		}
	});
	await client.send('Page.startScreencast', {
		format: 'jpeg',
		quality: 90,
		everyNthFrame: 1,
		maxWidth: VW * SCALE,
		maxHeight: VH * SCALE,
	});

	await page.waitForTimeout(500); // hold on the opening frame

	// Drive the timeline one step at a time (the built-in Play is fixed 1100ms).
	const next = page.locator('#anim-next');
	for (let i = 0; i < 200 && !(await next.isDisabled()); i++) {
		await next.click();
		await page.waitForTimeout(STEP_MS);
		track(await boxOf());
	}

	await page.waitForTimeout(900); // let the final merge settle
	await client.send('Page.stopScreencast');
	await context.close();
	await browser.close();

	if (frames.length < 2) throw new Error(`captured only ${frames.length} frame(s)`);

	// Build an ffmpeg concat list where each frame is held for the real elapsed
	// time until the next one — so static pauses hold and transitions play at the
	// true rate the browser painted them.
	const lines = [];
	for (let i = 0; i < frames.length; i++) {
		const dur = i < frames.length - 1 ? Math.max(0.001, frames[i + 1].ts - frames[i].ts) : HOLD_S;
		lines.push(`file '${frames[i].file}'`);
		lines.push(`duration ${dur.toFixed(4)}`);
	}
	lines.push(`file '${frames[frames.length - 1].file}'`); // concat needs the last file repeated
	const listPath = path.join(framesDir, 'frames.txt');
	writeFileSync(listPath, `${lines.join('\n')}\n`);

	// Even-sided crop rect around the column, clamped to the frame.
	const x = Math.max(0, Math.floor(acc.left - PAD));
	const y = Math.max(0, Math.floor(acc.top - PAD));
	let w = Math.ceil(acc.width + PAD * 2);
	let h = Math.ceil(acc.bottom - acc.top + PAD * 2);
	w = Math.min(w, VW * SCALE - x);
	h = Math.min(h, VH * SCALE - y);
	w -= w % 2;
	h -= h % 2;

	console.log(`captured ${frames.length} frames → resampling to ${FPS}fps`);
	console.log(`crop rect: ${w}x${h} at (${x}, ${y})`);

	execFileSync(
		'ffmpeg',
		[
			'-y',
			'-f', 'concat',
			'-safe', '0',
			'-i', listPath,
			'-vf', `crop=${w}:${h}:${x}:${y},fps=${FPS}`,
			'-c:v', 'libx264',
			'-pix_fmt', 'yuv420p',
			'-movflags', '+faststart',
			finalOut,
		],
		{ stdio: 'inherit' },
	);

	if (!process.env.KEEP_RAW) rmSync(framesDir, { recursive: true, force: true });
	console.log('wrote', finalOut);
})();
