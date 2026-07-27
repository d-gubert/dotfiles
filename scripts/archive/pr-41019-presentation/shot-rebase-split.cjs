// Render each .slide in pr-41019-rebase-split.html to a 16:9 PNG (2560x1440 @ 2x).
// Usage: node shot-rebase-split.cjs   →   pr-41019-rebase-split/slide-1.png ... slide-6.png
const { existsSync, readdirSync, mkdirSync } = require('fs');
const path = require('path');

const { chromium } = require('playwright');

// The repo's Playwright and the npx-installed browser can disagree on the
// chromium build number, so find whatever chrome is actually in the cache.
function findChrome() {
	try {
		const p = chromium.executablePath();
		if (existsSync(p)) return p; // versions match — use the default
	} catch { }
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
	const file = `file://${path.resolve(__dirname, 'pr-41019-rebase-split.html')}`;
	const outdir = path.resolve(__dirname, 'pr-41019-rebase-split');
	mkdirSync(outdir, { recursive: true });

	const browser = await chromium.launch({ executablePath: findChrome() });
	const page = await browser.newPage({
		viewport: { width: 1280, height: 720 }, // each .slide is exactly 1280x720
		deviceScaleFactor: 2, // 2x → 2560x1440 PNGs, crisp for projection
	});
	await page.goto(file, { waitUntil: 'networkidle' });

	const slides = await page.$$('.slide');
	let i = 1;
	for (const s of slides) {
		const out = path.join(outdir, `slide-${i}.png`);
		await s.screenshot({ path: out });
		console.log('wrote', out);
		i++;
	}

	await browser.close();
})();
