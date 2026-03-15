import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Global navigation', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('supports mobile keyboard navigation patterns', async ({ page }) => {
    await page.setViewportSize({ width: 414, height: 896 });
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const nav = page.locator('#site-nav');
    const toggle = page.locator('.nav-toggle');
    const firstLink = nav.locator('.nav-link').first();

    await expect(nav).toHaveAttribute('data-open', 'false');
    await toggle.focus();
    await page.keyboard.press('Enter');

    await expect(nav).toHaveAttribute('data-open', 'true');
    await expect(toggle).toHaveAttribute('aria-expanded', 'true');

    await page.keyboard.press('Tab');
    await expect(firstLink).toBeFocused();

    await page.keyboard.press('Escape');
    await expect(nav).toHaveAttribute('data-open', 'false');
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await expect(toggle).toBeFocused();
  });
});
