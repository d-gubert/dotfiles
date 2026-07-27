// Screenshot the #41019 <summary> in the "The subject PRs" card.
// Usage: node shot-summary.cjs
//   optional env: PR=41103  (capture a different PR's summary row)
const { chromium } = require('playwright');
const { existsSync, readdirSync } = require('fs');
const path = require('path');

// The repo's Playwright and the npx-installed browser can disagree on the
// chromium build number, so find whatever chrome is actually in the cache.
function findChrome() {
  try {
    const p = chromium.executablePath();
    if (existsSync(p)) return p; // versions match — use the default
  } catch {}
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
  const PR = process.env.PR || '41019';
  const file = 'file://' + path.resolve(__dirname, 'pr-41019-timeline.src.html');
  const out = path.resolve(__dirname, `summary-${PR}.png`);

  const browser = await chromium.launch({ executablePath: findChrome() });
  const page = await browser.newPage({
    viewport: { width: 1280, height: 900 },
    deviceScaleFactor: 2, // 2x = crisp PNG
  });
  await page.goto(file, { waitUntil: 'networkidle' });

  // Scope to the "The subject PRs" card, then the <details> whose PR number matches.
  const card = page.locator('.card', {
    has: page.locator('.c-title', { hasText: 'The subject PRs' }),
  });
  const summary = card
    .locator('details', { has: page.locator('.prnum', { hasText: `#${PR}` }) })
    .locator('summary')
    .first();

  await summary.scrollIntoViewIfNeeded();
  await summary.screenshot({ path: out });
  console.log('wrote', out);

  await browser.close();
})();
