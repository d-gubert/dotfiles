/*
 * Work out how to put a page of an exact size on the virtual display, and where it lands.
 *
 * A headed Chromium draws its own frame - a tab strip, an omnibox, a thin border - and no window
 * manager is there to resize it. So two numbers are unknown:
 *
 *   1. the `--window-size` that makes the content area exactly the size the recording wants
 *   2. where that content area sits on the screen, which is the crop rectangle for ffmpeg
 *
 * Both belong to the Chromium build, not to the scenario, so `record.sh` caches them.
 *
 * This script solves (1) by launching, measuring, correcting the request and launching again. It
 * solves (2) by painting one solid magenta page, grabbing a frame of the screen with ffmpeg and
 * reading the rectangle out of the raw pixels - a measured crop, not a guess.
 *
 * Usage: node calibrate.js <pageWidth>x<pageHeight> <screenWidth>x<screenHeight>
 *   prints the geometry as shell assignments on stdout, ready to be cached:
 *     WINDOW_SIZE, CROP_X, CROP_Y, CROP_W, CROP_H, FIT_INNER
 *   exits 1 and explains on stderr when the screen holds no magenta page.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

const [targetWidth, targetHeight] = (process.argv[2] || '1280x720').split('x').map(Number);
const [screenWidth, screenHeight] = (process.argv[3] || '1360x960').split('x').map(Number);

const launch = async (requestWidth, requestHeight) => {
	const browser = await chromium.launch({
		headless: false,
		args: ['--use-gl=egl', '--window-position=0,0', `--window-size=${requestWidth},${requestHeight}`],
	});
	// viewport null keeps the page at the window's own size. An emulated viewport would make
	// Chromium scale the page into the content area, and the recording would resample every glyph.
	const page = await browser.newPage({ viewport: null });
	return { browser, page };
};

const measure = async (requestWidth, requestHeight) => {
	const { browser, page } = await launch(requestWidth, requestHeight);
	const inner = await page.evaluate(() => [window.innerWidth, window.innerHeight]);
	await browser.close();
	return inner;
};

/* Grab one frame of the whole screen as raw rgb24 bytes. */
const grabFrame = () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'record-ui-video-cal-'));
	const file = path.join(dir, 'screen.rgb');
	execFileSync(
		'ffmpeg',
		// prettier-ignore
		[
			'-y', '-hide_banner', '-loglevel', 'error',
			'-f', 'x11grab', '-draw_mouse', '0',
			'-video_size', `${screenWidth}x${screenHeight}`, '-i', process.env.DISPLAY,
			'-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', file,
		],
		{ stdio: ['ignore', 'ignore', 'inherit'] },
	);
	const data = fs.readFileSync(file);
	fs.rmSync(dir, { recursive: true, force: true });
	return data;
};

/* The bounding box of the magenta pixels in that frame, or null when there are none. */
const magentaRect = (data) => {
	const stride = screenWidth * 3;
	let top = -1;
	let bottom = -1;
	let left = -1;
	let right = -1;

	for (let y = 0; y < screenHeight; y++) {
		let first = -1;
		let last = -1;
		for (let x = 0; x < screenWidth; x++) {
			const at = y * stride + x * 3;
			if (data[at] !== 0xff || data[at + 1] !== 0x00 || data[at + 2] !== 0xff) {
				continue;
			}
			if (first < 0) {
				first = x;
			}
			last = x;
		}
		if (first < 0) {
			continue;
		}
		if (top < 0) {
			top = y;
		}
		bottom = y;
		left = left < 0 ? first : Math.min(left, first);
		right = right < 0 ? last : Math.max(right, last);
	}

	return top < 0 ? null : { x: left, y: top, width: right - left + 1, height: bottom - top + 1 };
};

(async () => {
	// A first guess at the frame: ~8px of border, ~92px of tab strip plus omnibox.
	let requestWidth = targetWidth + 8;
	let requestHeight = targetHeight + 92;
	let inner = [0, 0];

	for (let attempt = 0; attempt < 4; attempt++) {
		inner = await measure(requestWidth, requestHeight);
		if (inner[0] === targetWidth && inner[1] === targetHeight) {
			break;
		}
		requestWidth += targetWidth - inner[0];
		requestHeight += targetHeight - inner[1];
	}

	const { browser, page } = await launch(requestWidth, requestHeight);
	await page.setContent('<body style="margin:0;width:100vw;height:100vh;background:#ff00ff"></body>');
	await page.waitForTimeout(500);
	let rect = null;
	try {
		rect = magentaRect(grabFrame());
	} finally {
		await browser.close();
	}

	if (!rect) {
		console.error('calibrate.js: the calibration frame held no page, so the crop is unknown.');
		process.exit(1);
	}

	process.stdout.write(
		[
			`WINDOW_SIZE=${requestWidth},${requestHeight}`,
			`CROP_X=${rect.x}`,
			`CROP_Y=${rect.y}`,
			`CROP_W=${rect.width}`,
			`CROP_H=${rect.height}`,
			`FIT_INNER=${inner[0]}x${inner[1]}`,
			'',
		].join('\n'),
	);
})().catch((error) => {
	console.error(`calibrate.js: ${error.message}`);
	process.exit(1);
});
