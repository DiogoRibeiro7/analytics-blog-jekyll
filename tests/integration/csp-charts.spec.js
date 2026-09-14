import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

// Plotly and the Jupyter widget manager render only under the looser policy
// their pages get (#195). These load the real libraries from their CDNs, as the
// pages with math already load MathJax, and fail on any script or style
// violation.
const recordViolations = (page) =>
  page.addInitScript(() => {
    window.cspViolations = [];
    document.addEventListener('securitypolicyviolation', (event) => {
      window.cspViolations.push(`${event.effectiveDirective} ${event.blockedURI}`);
    });
  });

const scriptAndStyleViolations = (page) =>
  page.evaluate(() => window.cspViolations.filter((entry) => /^(script|style)-src/.test(entry)));

test.describe('Charts under the Content Security Policy', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('Plotly renders on a post', async ({ page }) => {
    await recordViolations(page);
    await page.goto(new URL('/2024/04/07/data-visualization-plotly-showcase/', baseUrl).href, { waitUntil: 'load' });

    const block = page.locator('[data-viz-type="plotly"]');
    await block.scrollIntoViewIfNeeded();
    await expect(block.locator('.main-svg').first()).toBeVisible({ timeout: 30000 });
    expect(await scriptAndStyleViolations(page)).toEqual([]);
  });

  test('Plotly and a Jupyter widget render on the gallery', async ({ page }) => {
    await recordViolations(page);
    await page.goto(new URL('/visualizations/', baseUrl).href, { waitUntil: 'load' });

    const plotly = page.locator('[data-viz-type="plotly"]');
    await plotly.scrollIntoViewIfNeeded();
    await expect(plotly.locator('.main-svg').first()).toBeVisible({ timeout: 30000 });

    const widget = page.locator('[data-viz-type="ipywidgets"]');
    await widget.scrollIntoViewIfNeeded();
    await expect(widget.locator('.widget-slider').first()).toBeVisible({ timeout: 30000 });

    expect(await scriptAndStyleViolations(page)).toEqual([]);
  });
});
