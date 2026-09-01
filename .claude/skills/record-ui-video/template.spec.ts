/**
 * Throwaway screen-recording spec. Copy into apps/meteor/tests/e2e/demos/<name>-demo.spec.ts,
 * edit the scenario, run it with `scripts/record.sh`, keep the video. See the record-ui-video skill.
 *
 * It is a recording, not an assertion suite: the expects only gate the video so a broken run does
 * not record a broken screen. The parts that make recording work are marked KEEP.
 *
 * ffmpeg records this run off a virtual display; Playwright's own recorder stays off.
 */
import type { Locator, Page } from '@playwright/test';

import { Users } from '../fixtures/userStates';
import { HomeChannel } from '../page-objects';
import { installLocalTestPackage, uninstallApp } from '../utils/apps';
import { expect, test } from '../utils/test';

// If the scenario needs a custom app, point this at an absolute path to a hand-built zip.
// const CUSTOM_APP_ZIP = '/absolute/path/to/app_0.0.1.zip';

/**
 * KEEP: draws the pointer as a visible dot, so the recording shows where each click lands.
 * `page.mouse` moves a synthetic cursor inside the browser and never moves the X pointer, so the
 * capture runs with `-draw_mouse 0` and this dot is the only cursor in the video.
 */
const showPointer = (page: Page): Promise<void> =>
	page.addInitScript(() => {
		const draw = (): void => {
			const dot = document.createElement('div');
			dot.style.cssText = [
				'position:fixed',
				'z-index:2147483647',
				'width:22px',
				'height:22px',
				'margin:-11px 0 0 -11px',
				'border-radius:50%',
				'background:rgba(30,136,229,0.35)',
				'border:2px solid rgba(30,136,229,0.9)',
				'pointer-events:none',
				'transition:transform 0.08s ease-out',
				'left:0',
				'top:0',
			].join(';');
			document.body.appendChild(dot);
			document.addEventListener(
				'mousemove',
				(event) => {
					dot.style.left = `${event.clientX}px`;
					dot.style.top = `${event.clientY}px`;
				},
				true,
			);
		};
		if (document.body) {
			draw();
		} else {
			window.addEventListener('DOMContentLoaded', draw);
		}
	});

/** KEEP: a deliberate beat, so the viewer can read the screen between steps. */
const beat = (page: Page, ms = 1400): Promise<void> => page.waitForTimeout(ms);

/**
 * KEEP: glide the pointer to a target, then click it, so the recording captures smooth motion.
 * A raw click teleports the cursor, which reads as a jump. Each `steps` move is a mouse event the
 * compositor renders, and ffmpeg grabs the display 60 times a second, so the glide is smooth.
 * Prefer this over `locator.click()` for any click the viewer watches.
 */
const glideClick = async (page: Page, target: Locator, steps = 24): Promise<void> => {
	await target.waitFor({ state: 'visible' });
	const box = await target.boundingBox();
	if (!box) {
		throw new Error('glideClick: target has no bounding box');
	}
	await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps });
	await page.mouse.down();
	await page.mouse.up();
};

/**
 * KEEP: the size of the page in the video. `record.sh` reads this line to size the virtual display
 * and to calibrate the browser frame, so keep the name and the `WIDTHxHEIGHT` shape.
 */
const RECORD_VIEWPORT = '1280x720';

// `record.sh` measures the --window-size that leaves a content area of exactly RECORD_VIEWPORT and
// passes it back here. The fallback only applies when someone runs the spec by hand: 87px is the
// tab strip plus the omnibox of a current Chromium.
const [recordWidth, recordHeight] = RECORD_VIEWPORT.split('x').map(Number);
const windowSize = process.env.RECORD_WINDOW_SIZE ?? `${recordWidth},${recordHeight + 87}`;

// KEEP: this block is what makes the ffmpeg capture work.
//  - headless false      : a real Chromium window on the virtual display, which ffmpeg can grab
//  - viewport null       : the page takes the window's own size, so no pixel is ever rescaled
//  - video off           : Playwright's recorder would only duplicate the capture, slowly
//  - window-position 0,0 : the window lands where the calibrated crop expects it
//  - autoplay-policy     : ringtones and call audio play with no user gesture, so audio records
// `launchOptions` REPLACES the array in playwright.config.ts, so the fake-media args are repeated
// here. Without them a call cannot get a microphone.
test.use({
	headless: false,
	viewport: null,
	storageState: Users.user1.state,
	video: 'off',
	launchOptions: {
		args: [
			'--use-gl=egl',
			'--use-fake-ui-for-media-stream',
			'--use-fake-device-for-media-stream',
			'--autoplay-policy=no-user-gesture-required',
			'--window-position=0,0',
			`--window-size=${windowSize}`,
		],
	},
});

test.describe('<scenario> - demo recording', () => {
	test.beforeAll(async ({ api }) => {
		// `api` is the admin REST context. Do setup here, not on screen.
		await Promise.all([
			api.post('/users.setStatus', { status: 'online', username: 'user1' }),
			api.post('/users.setStatus', { status: 'online', username: 'user2' }),
		]);

		// const { app } = await installLocalTestPackage(CUSTOM_APP_ZIP);
		// appId = app.id;
	});

	test.afterAll(async () => {
		// await uninstallApp(appId);
	});

	test('<one sentence describing the flow>', async ({ page }) => {
		await showPointer(page);
		const home = new HomeChannel(page);

		await page.goto('/');
		await page.locator('role=navigation').first().waitFor();
		await beat(page);

		await test.step('step one', async () => {
			await home.navbar.openChat('user2');
			await expect(home.composer.inputMessage).toBeVisible();
			await beat(page);
		});

		await test.step('step two - a smooth click', async () => {
			// Prefer glideClick over locator.click() for a click the viewer watches: it moves the
			// cursor to the target in steps, so the recording glides instead of teleporting.
			await glideClick(page, home.composer.inputMessage);
			await beat(page);
		});

		// … drive the rest of the scenario. Locator hygiene:
		//  - newest message: home.content.lastUserMessage (toContainText), not page.getByText
		//  - a panel: page.getByRole('dialog', { name: '<title>' }) then scope inside it
		//  - a list row: page.getByRole('link').filter({ hasText }).first()
		//  - close a lingering call dialer (home.voiceCalls.widget.btnClose) before navigating
		//  - watched clicks: glideClick(page, <locator>) for smooth pointer motion, not locator.click()
	});
});

// Silences unused-import lint while the app lines are commented out
void installLocalTestPackage;
void uninstallApp;
