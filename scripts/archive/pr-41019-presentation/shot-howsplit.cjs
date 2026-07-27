// Render the restyled "How split?" slide + standalone monolith card to PNGs @2x.
const { existsSync, readdirSync, mkdirSync } = require('fs');
const path = require('path');
const { chromium } = require('playwright');

function findChrome() {
	try { const p = chromium.executablePath(); if (existsSync(p)) return p; } catch {}
	const cache = path.join(process.env.HOME, '.cache', 'ms-playwright');
	for (const d of readdirSync(cache).filter((n) => n.startsWith('chromium-'))) {
		for (const sub of ['chrome-linux64/chrome', 'chrome-linux/chrome']) {
			const c = path.join(cache, d, sub);
			if (existsSync(c)) return c;
		}
	}
	return undefined;
}

(async () => {
	const file = `file://${path.resolve(__dirname, 'pr-41019-howsplit-restyle.html')}`;
	const outdir = path.resolve(__dirname, 'pr-41019-howsplit');
	mkdirSync(outdir, { recursive: true });
	const browser = await chromium.launch({ executablePath: findChrome() });
	const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
	await page.goto(file, { waitUntil: 'networkidle' });
	for (const [sel, name] of [['#slide', 'slide'], ['#card-solo', 'card-only']]) {
		const el = await page.$(sel);
		const out = path.join(outdir, `${name}.png`);
		await el.screenshot({ path: out, omitBackground: name === 'card-only' });
		console.log('wrote', out);
	}
	await browser.close();
})();
