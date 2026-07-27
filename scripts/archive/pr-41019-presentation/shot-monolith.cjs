// Screenshot the "The opening monolith" PR card (#41019, #tree-origin) in its
// expanded state — the full <details> block with the file tree open.
// Usage: node shot-monolith.cjs   →   monolith-open.png
const { existsSync, readdirSync } = require('fs');
const path = require('path');

const { chromium } = require('playwright');

// The repo's Playwright and the npx-installed browser can disagree on the
// chromium build number, so find whatever chrome is actually in the cache.
function findChrome() {
	try {
		const p = chromium.executablePath();
		if (existsSync(p)) return p; // versions match — use the default
	} catch {
		// shut up
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

(async () => {
	const file = `file://${path.resolve(__dirname, 'pr-41019-timeline.src.html')}`;
	const out = path.resolve(__dirname, 'monolith-open.png');

	const browser = await chromium.launch({ executablePath: findChrome() });
	const page = await browser.newPage({
		viewport: { width: 1280, height: 900 },
		deviceScaleFactor: 2, // 2x = crisp PNG
	});
	await page.goto(file, { waitUntil: 'networkidle' });

	// The "opening monolith" card is the <details> holding #tree-origin.
	const details = page.locator('details', {
		has: page.locator('#tree-origin'),
	});

	// Force it open, then wait for the tree to finish rendering (it starts as
	// the "Loading file tree…" placeholder and is replaced with .tnode rows).
	await details.evaluate((el) => el.setAttribute('open', ''));
	await details.locator('#tree-origin .tnode').first().waitFor();

	await details.scrollIntoViewIfNeeded();
	await details.screenshot({ path: out });
	console.log('wrote', out);

	await browser.close();
})();
