import fs from 'node:fs';
import { createRequire } from 'node:module';

import { expect, test } from '@playwright/test';

/**
 * Colour contrast, in both themes.
 *
 * The Pa11y workflow uses HTML CodeSniffer and only ever sees light mode, which
 * is why a heading rendering white on white in dark mode went unnoticed. This
 * runs axe-core's colour-contrast rule, the same engine Lighthouse uses, over
 * both themes.
 */

const require = createRequire(import.meta.url);
const axeSource = fs.readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

// One page per family of components: cards and badges, the gallery, project
// cards, the search application, and a post with citation tools and code.
const PAGES = [
  '/',
  '/blog/',
  '/visualizations/',
  '/portfolio/',
  '/search/',
  '/2024/01/01/introducing-datalog/',
];

// axe has to be injected as an inline script, which the site's Content Security
// Policy forbids. The policy itself is covered by tests/test_csp.rb.
test.use({ bypassCSP: true });

for (const theme of ['light', 'dark']) {
  test.describe(`Colour contrast (${theme} mode)`, () => {
    for (const path of PAGES) {
      test(`${path} has no contrast violations`, async ({ page }) => {
        // Set the preference the way the theme stores it, before any script runs.
        await page.addInitScript((mode) => {
          window.localStorage.setItem('datalog-color-mode', mode);
        }, theme);

        await page.goto(`${baseUrl}${path}`, { waitUntil: 'load' });
        await expect(page.locator('body')).toHaveAttribute('data-theme', theme);

        await page.addScriptTag({ content: axeSource });
        const results = await page.evaluate(async () =>
          window.axe.run(document, { runOnly: { type: 'rule', values: ['color-contrast'] } })
        );

        const failures = results.violations.flatMap((violation) =>
          violation.nodes.map((node) => {
            const data = node.any?.[0]?.data || {};
            return `${node.target.join(' ')}: ${data.fgColor} on ${data.bgColor} = ${data.contrastRatio} (needs ${data.expectedContrastRatio})`;
          })
        );

        expect(failures, `Contrast failures in ${theme} mode on ${path}`).toEqual([]);
      });
    }
  });
}
