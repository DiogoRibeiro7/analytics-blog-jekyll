import { expect, test } from '@playwright/test';
import { capturePercySnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadSearchPage(page) {
  await page.goto(`${normalizedBaseUrl}/search/`, { waitUntil: 'networkidle' });
  await page.waitForLoadState('networkidle');
  await stabilizePage(page);
}

test.describe('Search page visual scenarios', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  for (const viewport of viewports) {
    test.describe(`${viewport.name} viewport`, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      test.beforeEach(async ({ page }) => {
        await loadSearchPage(page);
      });

      test(`@visual search interface shell (${viewport.name})`, async ({ page }) => {
        const searchPanel = page.locator('.search-app__panel');
        await expect(searchPanel).toBeVisible();

        const formLabel = await searchPanel.locator('.search-app__label').textContent();
        expect((formLabel ?? '').trim()).toBe('Query');

        const shortcuts = await searchPanel.locator('[data-search-shortcuts]').textContent();
        expect((shortcuts ?? '').includes('Keyboard shortcuts')).toBeTruthy();

        await capturePercySnapshot(page, `Search interface (${viewport.name})`, {
          scope: '.search-app__panel'
        });
      });

      test(`@visual search filters (${viewport.name})`, async ({ page }) => {
        const filters = page.locator('.search-app__filters');
        await expect(filters).toBeVisible();

        const selects = filters.locator('select');
        const selectCount = await selects.count();
        expect(selectCount).toBeGreaterThanOrEqual(3);
        const filterLegend = (await filters.locator('legend').textContent())?.trim();
        expect(filterLegend).toBe('Advanced filters');

        const tagGroup = filters.locator('[data-filter-tags]');
        expect(await tagGroup.getAttribute('role')).toBe('group');

        await capturePercySnapshot(page, `Search filters (${viewport.name})`, {
          scope: '.search-app__filters'
        });
      });

      test(`@visual search results populated (${viewport.name})`, async ({ page }) => {
        const queryInput = page.locator('[data-search-input]');
        await queryInput.fill('python');
        await page.waitForTimeout(400);
        await page.waitForSelector('[data-search-results] li');
        const resultsList = page.locator('.search-app__results');
        await expect(resultsList).toBeVisible();

        const liveRegion = resultsList.locator('[data-search-live="count"]');
        const liveText = (await liveRegion.textContent())?.trim() ?? '';
        expect(liveText.length).toBeGreaterThan(0);

        const firstResult = page.locator('[data-search-results] li').first();
        await expect(firstResult).toBeVisible();
        const titleText = (await firstResult.locator('.search-result__title').textContent())?.trim() ?? '';
        expect(titleText.length).toBeGreaterThan(0);

        const detailLink = await firstResult.locator('[data-result-link]').getAttribute('href');
        expect(detailLink).toBeTruthy();

        await capturePercySnapshot(page, `Search results (${viewport.name})`, {
          scope: '.search-app__results'
        });
      });
    });
  }
});
