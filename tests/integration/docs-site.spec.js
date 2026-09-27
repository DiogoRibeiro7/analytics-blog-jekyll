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

test.describe('Documentation homepage', () => {
  test.skip(!process.env.DOCS_SITE_TESTS, 'Run against the built docs/site preview.');

  test('the two actions and three feature cards reach published pages', async ({ page }) => {
    await page.goto('/');
    const actions = page.locator('.hero-actions a');
    const cards = page.locator('.home-feature-card a');
    await expect(actions).toHaveCount(2);
    await expect(actions.first()).toHaveText('Get started');
    await expect(cards).toHaveCount(3);
    await expect(page.locator('.section-highlight article')).toHaveCount(2);
    await expect(page.locator('.section-portfolio article')).toHaveCount(1);
    await actions.first().focus();
    await page.keyboard.press('Tab');
    await expect(actions.nth(1)).toBeFocused();

    for (const link of await page.locator('.hero-actions a, .home-feature-card a').all()) {
      const href = await link.getAttribute('href');
      const response = await page.request.get(new URL(href, page.url()).href);
      expect(response.ok(), `${href} should be a published docs page`).toBe(true);
    }
  });

  for (const width of [390, 1280]) {
    for (const mode of ['dark', 'light']) {
      test(`the landing layout fits ${width}px in ${mode} mode`, async ({ page }) => {
        await page.setViewportSize({ width, height: 860 });
        await page.goto('/');
        if (mode === 'light') await page.locator('[data-toggle-dark-mode]').click();

        await expect(page.locator('body')).toHaveAttribute('data-theme', mode);
        await expect(page.locator('.hero--contained')).toBeVisible();
        await expect(page.locator('.home-feature-card')).toHaveCount(3);
        await expect(page.locator('.section-intro .card')).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
      });
    }
  }
});

test.describe('Documentation technical content', () => {
  test.skip(!process.env.DOCS_SITE_TESTS, 'Run against the built docs/site preview.');

  test('technical examples, guide links, and code copying work', async ({ page }) => {
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
    await page.goto('/guides/technical-content/');
    await expect(page.locator('.docs-sidebar [aria-current="page"]')).toHaveText('Technical content');
    await expect(page.locator('.docs-content .code-copy')).toHaveCount(2);
    await expect(page.locator('.docs-content table caption')).toHaveText('Example observations used to estimate the mean');
    await expect(page.locator('.docs-content .callout[role="note"]')).toBeVisible();
    await expect(page.locator('.docs-on-this-page a[href="#equations"]')).toBeVisible();

    const copy = page.locator('.docs-content .code-copy').first();
    await copy.click();
    await expect(copy).toHaveText('Copied!');
    expect(await page.evaluate(() => navigator.clipboard.readText())).toContain('layout: post');
    await page.locator('.docs-on-this-page a[href="#equations"]').click();
    await expect(page).toHaveURL(/#equations$/);
  });

  for (const width of [390, 1280]) {
    for (const mode of ['dark', 'light']) {
      test(`technical guide fits ${width}px in ${mode} mode`, async ({ page }) => {
        await page.setViewportSize({ width, height: 860 });
        await page.goto('/guides/technical-content/');
        if (mode === 'light') await page.locator('[data-toggle-dark-mode]').click();

        await expect(page.locator('body')).toHaveAttribute('data-theme', mode);
        await expect(page.locator('.docs-content table')).toBeVisible();
        await expect(page.locator('.docs-content .math-expression')).toBeVisible();
        await expect(page.locator('.docs-content .callout')).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
      });
    }
  }
});
