import { expect, test } from '@playwright/test';
import { captureSnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadHomepage(page) {
  await page.goto(`${normalizedBaseUrl}/`, { waitUntil: 'networkidle' });
  await page.waitForLoadState('networkidle');
  await stabilizePage(page);
}

test.describe('Homepage visual scenarios', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  for (const viewport of viewports) {
    test.describe(`${viewport.name} viewport`, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      test.beforeEach(async ({ page }) => {
        await loadHomepage(page);
      });

      test(`@visual homepage hero section (${viewport.name})`, async ({ page }) => {
        const heroSection = page.locator('section.hero');
        await expect(heroSection).toBeVisible();

        const heading = heroSection.locator('h1, h2').first();
        const headingText = (await heading.textContent())?.trim() ?? '';
        expect(headingText.length).toBeGreaterThan(0);

        const heroMetrics = await heroSection.evaluate((node) => {
          const rect = node.getBoundingClientRect();
          const style = window.getComputedStyle(node);
          return {
            height: rect.height,
            paddingTop: parseFloat(style.paddingTop),
            paddingBottom: parseFloat(style.paddingBottom)
          };
        });

        expect(heroMetrics.height).toBeGreaterThan(240);
        expect(heroMetrics.paddingTop).toBeGreaterThanOrEqual(24);
        expect(heroMetrics.paddingBottom).toBeGreaterThanOrEqual(24);

        const ctas = heroSection.getByRole('link');
        const ctaCount = await ctas.count();
        expect(ctaCount).toBeGreaterThanOrEqual(1);

        await captureSnapshot(page, `Homepage hero (${viewport.name})`, {
          scope: 'section.hero'
        });
      });

      test(`@visual homepage featured posts (${viewport.name})`, async ({ page }) => {
        const featuredGrid = page.locator('.section-highlight .card-grid');
        await expect(featuredGrid).toBeVisible();

        const cards = featuredGrid.locator('.card');
        const cardCount = await cards.count();
        expect(cardCount).toBeGreaterThanOrEqual(3);

        const firstCard = cards.first();
        const cardHeading = (await firstCard.locator('h3').textContent())?.trim() ?? '';
        expect(cardHeading.length).toBeGreaterThan(0);

        const cardLinkHref = await firstCard.getByRole('link').getAttribute('href');
        expect(cardLinkHref).toBeTruthy();
        if (cardLinkHref) {
          expect(cardLinkHref).toMatch(/\S/);
        }

        await captureSnapshot(page, `Homepage featured posts (${viewport.name})`, {
          scope: '.section-highlight .card-grid'
        });
      });
    });
  }
});
