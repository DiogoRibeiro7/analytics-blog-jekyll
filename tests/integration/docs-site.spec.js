import { expect, test } from '@playwright/test';

test.describe('Documentation guide', () => {
  test.skip(!process.env.DOCS_SITE_TESTS, 'Run against the built docs/site preview.');

  for (const mode of ['dark', 'light']) {
    test(`guide navigation, search and copy work at phone width in ${mode} mode`, async ({ page }) => {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto('/guides/installation/');
      if (mode === 'light') {
        await page.locator('[data-toggle-dark-mode]').click();
      }
      await expect(page.locator('body')).toHaveAttribute('data-theme', mode);
      await expect(page.locator('.docs-sidebar [aria-current="page"]')).toHaveText('Installation');
      await expect(page.locator('.docs-on-this-page a[href="#requirements"]')).toBeVisible();
      await expect(page.locator('.docs-content .code-copy')).toHaveCount(3);
      await page.locator('.docs-content .code-copy').first().focus();
      await expect(page.locator('.docs-content .code-copy').first()).toBeFocused();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);

      await page.locator('.docs-pagination a[href="/guides/configuration/"]').click();
      await expect(page).toHaveURL(/\/guides\/configuration\/$/);
      await expect(page.locator('.docs-sidebar [aria-current="page"]')).toHaveText('Configuration');

      await page.locator('.site-search input[type="search"]').fill('Install DataLog');
      await page.locator('.site-search button').click();
      await expect(page).toHaveURL(/\/search\/\?q=Install/);
      await expect(page.locator('.search-result__title a').first()).toBeVisible();
    });
  }
});
