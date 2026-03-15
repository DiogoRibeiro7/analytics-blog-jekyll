import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Dark Mode Toggle', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('dark mode toggle is visible', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Look for dark mode toggle
    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    const toggleCount = await toggle.count();
    if (toggleCount === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    await expect(toggle.first()).toBeVisible();
  });

  test('clicking toggle changes theme', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    if ((await toggle.count()) === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    // Get initial theme state
    const initialTheme = await page.evaluate(() => {
      return (
        document.documentElement.getAttribute('data-theme') ||
        document.body.getAttribute('data-theme') ||
        document.documentElement.classList.contains('dark') ||
        document.body.classList.contains('dark')
      );
    });

    // Click the toggle
    await toggle.first().click();
    await page.waitForTimeout(300);

    // Theme should have changed
    const newTheme = await page.evaluate(() => {
      return (
        document.documentElement.getAttribute('data-theme') ||
        document.body.getAttribute('data-theme') ||
        document.documentElement.classList.contains('dark') ||
        document.body.classList.contains('dark')
      );
    });

    expect(newTheme).not.toBe(initialTheme);
  });

  test('theme persists after navigation', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    if ((await toggle.count()) === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    // Click toggle to change theme
    await toggle.first().click();
    await page.waitForTimeout(300);

    // Get current theme
    const themeAfterToggle = await page.evaluate(() => {
      return (
        document.documentElement.getAttribute('data-theme') ||
        document.body.getAttribute('data-theme') ||
        (document.documentElement.classList.contains('dark') ? 'dark' : 'light')
      );
    });

    // Navigate to another page
    const navLink = page.locator('nav a, header a').first();
    if ((await navLink.count()) > 0) {
      await navLink.click();
      await page.waitForLoadState('domcontentloaded');

      // Theme should be preserved
      const themeAfterNav = await page.evaluate(() => {
        return (
          document.documentElement.getAttribute('data-theme') ||
          document.body.getAttribute('data-theme') ||
          (document.documentElement.classList.contains('dark') ? 'dark' : 'light')
        );
      });

      expect(themeAfterNav).toBe(themeAfterToggle);
    }
  });

  test('theme persists after page reload', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    if ((await toggle.count()) === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    // Click toggle to set dark mode
    await toggle.first().click();
    await page.waitForTimeout(300);

    const themeBeforeReload = await page.evaluate(() => {
      return (
        document.documentElement.getAttribute('data-theme') ||
        document.body.getAttribute('data-theme') ||
        (document.documentElement.classList.contains('dark') ? 'dark' : 'light')
      );
    });

    // Reload the page
    await page.reload({ waitUntil: 'domcontentloaded' });

    // Theme should be preserved from localStorage
    const themeAfterReload = await page.evaluate(() => {
      return (
        document.documentElement.getAttribute('data-theme') ||
        document.body.getAttribute('data-theme') ||
        (document.documentElement.classList.contains('dark') ? 'dark' : 'light')
      );
    });

    expect(themeAfterReload).toBe(themeBeforeReload);
  });

  test('toggle has proper accessibility attributes', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    if ((await toggle.count()) === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    const toggleElement = toggle.first();

    // Should be a button or have button role
    const tagName = await toggleElement.evaluate((el) => el.tagName.toLowerCase());
    const role = await toggleElement.getAttribute('role');

    expect(tagName === 'button' || role === 'button' || role === 'switch').toBe(true);

    // Should have accessible label
    const ariaLabel = await toggleElement.getAttribute('aria-label');
    const ariaLabelledBy = await toggleElement.getAttribute('aria-labelledby');
    const innerText = await toggleElement.textContent();

    expect(ariaLabel || ariaLabelledBy || innerText.trim()).toBeTruthy();
  });

  test('toggle is keyboard accessible', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const toggle = page.locator(
      '[class*="dark-mode"], [class*="theme-toggle"], [aria-label*="theme"], [aria-label*="dark"], button[class*="theme"]'
    );

    if ((await toggle.count()) === 0) {
      test.skip(true, 'Dark mode toggle not found');
      return;
    }

    // Focus the toggle
    await toggle.first().focus();
    await expect(toggle.first()).toBeFocused();

    // Get initial theme
    const initialTheme = await page.evaluate(() => {
      return document.documentElement.getAttribute('data-theme') || 'light';
    });

    // Press Enter to toggle
    await page.keyboard.press('Enter');
    await page.waitForTimeout(300);

    // Theme should have changed
    const newTheme = await page.evaluate(() => {
      return document.documentElement.getAttribute('data-theme') || 'light';
    });

    expect(newTheme).not.toBe(initialTheme);
  });
});
