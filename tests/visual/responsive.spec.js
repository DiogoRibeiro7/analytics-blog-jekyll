import { expect, test } from '@playwright/test';
import { captureSnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadHomepage(page) {
  await page.goto(`${normalizedBaseUrl}/`, { waitUntil: 'networkidle' });
  await page.waitForLoadState('networkidle');
  await stabilizePage(page);
}

test.describe('Responsive homepage layouts', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  for (const viewport of viewports) {
    test.describe(viewport.name, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      test(`@visual homepage ${viewport.name}`, async ({ page }) => {
        await loadHomepage(page);

        const hero = page.locator('section.hero');
        await expect(hero).toBeVisible();

        const navToggle = page.locator('.nav-toggle');
        if (viewport.name === 'mobile') {
          await expect(navToggle).toBeVisible();
          expect(await navToggle.getAttribute('aria-controls')).toBe('site-nav');
        } else {
          await expect(navToggle).toBeHidden();
        }

        const navState = await page.locator('#site-nav').getAttribute('data-open');
        expect(navState).toBe('true');

        const layoutShape = await page.evaluate(() => {
          const cards = Array.from(
            document.querySelectorAll('.section-highlight .card-grid .card')
          ).slice(0, 4);
          const tops = cards.map((card) => Math.round(card.getBoundingClientRect().top));
          const uniqueTopCount = new Set(tops).size;
          return {
            cardSample: cards.length,
            uniqueTopCount
          };
        });

        expect(layoutShape.cardSample).toBeGreaterThan(0);

        if (viewport.name === 'mobile') {
          expect(layoutShape.uniqueTopCount).toBe(layoutShape.cardSample);
        } else {
          expect(layoutShape.uniqueTopCount).toBeLessThan(layoutShape.cardSample);
        }

        await captureSnapshot(page, `Responsive homepage (${viewport.name})`, {
          fullPage: true
        });
      });
    });
  }
});
