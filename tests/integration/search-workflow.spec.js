import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Search workflow', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('supports debounced, accessible searching end-to-end', async ({ page }) => {
    await page.route('**/search.json', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 600));
      await route.continue();
    });

    await page.goto(`${baseUrl}/search/`, { waitUntil: 'networkidle' });

    await page.waitForFunction(
      () => document?.body?.dataset?.featureSearchState === 'ready',
      { timeout: 15000 }
    );

    const input = page.locator('[data-search-input]');
    const loading = page.locator('[data-search-loading]');
    const resultsList = page.locator('[data-search-results]');
    const liveCount = page.locator('[data-search-live="count"]');
    const liveSelection = page.locator('[data-search-live="selection"]');
    const liveStatus = page.locator('[data-search-live="status"]');

    await expect(input).toBeVisible();
    await expect(loading).toBeHidden();

    await input.fill('python');
    await page.waitForTimeout(350);
    await expect(loading).toBeVisible();

    const resultItems = resultsList.locator('.search-result');
    await expect(resultItems.first()).toBeVisible({ timeout: 15000 });

    await expect(liveCount).toContainText(/result/i);
    await expect(liveCount).not.toHaveAttribute('hidden', '');

    await input.focus();
    await page.keyboard.press('ArrowDown');

    const activeResult = resultsList.locator('.search-result.is-active').first();
    await expect(activeResult).toBeVisible();

    const activeId = await activeResult.getAttribute('id');
    if (activeId) {
      await expect(input).toHaveAttribute('aria-activedescendant', activeId);
    }
    await expect(liveSelection).toContainText(/Result 1/i);

    const initialUrl = page.url();
    await Promise.all([
      page.waitForNavigation({ url: (url) => url !== initialUrl }),
      page.keyboard.press('Enter')
    ]);
    await expect(page).not.toHaveURL(initialUrl);

    await page.goBack({ waitUntil: 'domcontentloaded' });

    await input.fill('python');
    await page.waitForTimeout(350);
    await expect(resultsList.locator('.search-result').first()).toBeVisible();

    await input.focus();
    await page.keyboard.press('Escape');

    await expect(liveStatus).toContainText(/cleared/i);
    await expect(input).toHaveValue('');
    await expect(resultsList.locator('.search-result')).toHaveCount(0, { timeout: 5000 });
  });
});
