// Record a small video of the #41019 column in the growth section's animation.
// Playwright records the whole viewport (it scales to recordVideo.size, it does
// not crop), so we record the real desktop layout, track the #41019 lane's
// bounding box as it grows/sheds, then crop the video to that column with ffmpeg.
//
// Usage: node record-growth-41019.cjs
//   env: STEP_MS=500  (ms between animation steps — lower = snappier video)
//        KEEP_RAW=1   (keep the uncropped full-viewport .webm too)
// Output: growth-41019-column.mp4
const { execFileSync } = require('child_process');
const { existsSync, readdirSync, rmSync } = require('fs');
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
const VH = 800; // tall enough that the peak ~21-commit column fits un-clipped
const STEP_MS = parseInt(process.env.STEP_MS || '1000', 10);
const PAD = 14; // breathing room around the column in the crop
// Playwright's video recorder captures at the viewport's CSS-pixel size and
// ignores deviceScaleFactor, so to raise real resolution we render the page
// larger via CSS zoom by SCALE and enlarge the viewport/crop to match.
const SCALE = parseFloat(process.env.SCALE || '2');

(async () => {
	const file = `file://${path.resolve(__dirname, 'pr-41019-growth.html')}`;
	const outDir = path.resolve(__dirname);
	const finalOut = path.join(outDir, 'growth-41019-column.mp4');

	const browser = await chromium.launch({ executablePath: findChrome() });
	const context = await browser.newContext({
		colorScheme: 'dark',
		viewport: { width: VW * SCALE, height: VH * SCALE },
		reducedMotion: 'no-preference', // let the FLIP / chip transitions play
		recordVideo: { dir: outDir, size: { width: VW * SCALE, height: VH * SCALE } },
	});
	const page = await context.newPage();
	await page.goto(file, { waitUntil: 'networkidle' });

	const lane = page.locator('.lane.is-source'); // the #41019 column
	await lane.waitFor();

	// Zoom the whole page so it fills the enlarged viewport at SCALE× the pixels.
	// getBoundingClientRect then reports coords in this scaled space, so the crop
	// math below stays correct.
	await page.evaluate((s) => {
		document.documentElement.style.zoom = String(s);
	}, SCALE);

	// Pin the animation stage near the top of the viewport so the whole column
	// (which grows downward) stays on-screen for the entire run.
	await page.locator('#anim-stage').evaluate((el) => {
		el.scrollIntoView({ block: 'start' });
		window.scrollBy(0, -32);
	});
	await page.waitForTimeout(200);

	// The lane's left/top/width are fixed (it's always the leftmost, top-aligned
	// column); only its height changes. Track the tallest bottom edge we see.
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

	await page.waitForTimeout(500); // brief hold on the opening frame

	// Drive the timeline one step at a time so we control pacing (the built-in
	// Play runs at a fixed 1100ms). Step via the "next" button until it disables.
	const next = page.locator('#anim-next');
	for (let i = 0; i < 200 && !(await next.isDisabled()); i++) {
		await next.click();
		await page.waitForTimeout(STEP_MS);
		track(await boxOf());
	}

	await page.waitForTimeout(900); // let the final merge settle + hold last frame

	await context.close(); // flushes the .webm to disk
	const rawWebm = await page.video().path();
	await browser.close();

	// Compute an even-sided crop rect around the column, clamped to the frame.
	const x = Math.max(0, Math.floor(acc.left - PAD));
	const y = Math.max(0, Math.floor(acc.top - PAD));
	let w = Math.ceil(acc.width + PAD * 2);
	let h = Math.ceil(acc.bottom - acc.top + PAD * 2);
	w = Math.min(w, VW * SCALE - x);
	h = Math.min(h, VH * SCALE - y);
	w -= w % 2;
	h -= h % 2; // yuv420p needs even dimensions

	console.log(`raw video: ${rawWebm}`);
	console.log(`crop rect: ${w}x${h} at (${x}, ${y})`);

	execFileSync(
		'ffmpeg',
		['-y', '-i', rawWebm, '-vf', `crop=${w}:${h}:${x}:${y}`, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', finalOut],
		{ stdio: 'inherit' },
	);

	if (!process.env.KEEP_RAW) rmSync(rawWebm, { force: true });
	console.log('wrote', finalOut);
})();
