import { expect, test } from '@playwright/test';
import { captureSnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadPage(page, path) {
  await page.goto(`${normalizedBaseUrl}${path}`, { waitUntil: 'networkidle' });
  await page.waitForLoadState('networkidle');
  await stabilizePage(page);
}

test.describe('Post layout visual scenarios', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  for (const viewport of viewports) {
    test.describe(`${viewport.name} viewport`, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      test(`@visual post header metadata (${viewport.name})`, async ({ page }) => {
        await loadPage(page, '/2024/04/08/mathematical-proof-numbered-equations/');
        const postHeader = page.locator('.post-meta');
        await expect(postHeader).toBeVisible();

        const metaTerms = await postHeader.locator('dt').allTextContents();
        expect(metaTerms).toEqual(expect.arrayContaining(['Published', 'Author', 'Reading time']));

        const readingTime = await postHeader.locator('[data-reading-time]').textContent();
        expect((readingTime ?? '').toLowerCase()).toContain('read');

        await captureSnapshot(page, `Post metadata (${viewport.name})`, {
          scope: '.post-meta'
        });
      });

      test(`@visual post code block styling (${viewport.name})`, async ({ page }) => {
        await loadPage(page, '/2024/04/02/python-pandas-feature-engineering/');
        const codeBlock = page.locator('.post-content pre').first();
        await expect(codeBlock).toBeVisible();

        const classList = await codeBlock.getAttribute('class');
        expect(classList ?? '').toContain('language-');

        const codeStyles = await codeBlock.evaluate((node) => {
          const style = window.getComputedStyle(node);
          return {
            backgroundColor: style.backgroundColor,
            fontFamily: style.fontFamily,
            overflow: style.overflowX
          };
        });

        expect(codeStyles.backgroundColor).not.toBe('rgba(0, 0, 0, 0)');
        expect(codeStyles.fontFamily.toLowerCase()).toContain('monospace');
        expect(codeStyles.overflow === 'auto' || codeStyles.overflow === 'scroll').toBeTruthy();

        await captureSnapshot(page, `Post code block (${viewport.name})`, {
          scope: '.post-content pre'
        });
      });

      test(`@visual post math rendering (${viewport.name})`, async ({ page }) => {
        await loadPage(page, '/2024/04/08/mathematical-proof-numbered-equations/');
        const equation = page.locator('.post-content .mjx-container').first();
        await expect(equation).toBeVisible();

        const ariaLabel = await equation.getAttribute('aria-label');
        expect(ariaLabel).toBeTruthy();

        const mathStyles = await equation.evaluate((node) => {
          const style = window.getComputedStyle(node);
          return {
            display: style.display,
            textAlign: style.textAlign
          };
        });

        expect(mathStyles.display).not.toBe('none');
        expect(mathStyles.textAlign).toMatch(/center|left|right|start|end/);

        await captureSnapshot(page, `Post math rendering (${viewport.name})`, {
          scope: '.post-content .mjx-container'
        });
      });
    });
  }
});
