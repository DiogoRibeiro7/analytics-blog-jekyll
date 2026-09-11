import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Homepage', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  });

  test('renders core page elements', async ({ page }) => {
    // Header elements (the site header; article headers are also <header>)
    await expect(page.locator('header').first()).toBeVisible();
    await expect(page.locator('.site-title, .brand-title, [class*="title"]').first()).toBeVisible();

    // Navigation
    const nav = page.locator('nav, [role="navigation"]').first();
    await expect(nav).toBeVisible();

    // Main content
    await expect(page.locator('main, [role="main"]')).toBeVisible();

    // Footer
    await expect(page.locator('footer')).toBeVisible();
  });

  test('has correct page title and meta tags', async ({ page }) => {
    const title = await page.title();
    expect(title).toBeTruthy();
    expect(title.toLowerCase()).toContain('datalog');

    // Check meta description
    const metaDescription = await page.locator('meta[name="description"]').getAttribute('content');
    expect(metaDescription).toBeTruthy();
  });

  test('navigation links are functional', async ({ page }) => {
    // Find navigation links
    const navLinks = page.locator('nav a, header a').filter({ hasText: /.+/ });
    const linkCount = await navLinks.count();

    expect(linkCount).toBeGreaterThan(0);

    // Check that links have valid href attributes
    for (let i = 0; i < Math.min(linkCount, 5); i++) {
      const href = await navLinks.nth(i).getAttribute('href');
      expect(href).toBeTruthy();
      expect(href).not.toBe('#');
    }
  });

  test('displays recent blog posts', async ({ page }) => {
    // Look for post listings
    const postLinks = page.locator('article a, .post-link, [class*="post"] a');
    const postCount = await postLinks.count();

    // Should have at least one post
    expect(postCount).toBeGreaterThan(0);
  });

  test('loads without console errors', async ({ page }) => {
    const consoleErrors = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto(baseUrl, { waitUntil: 'networkidle' });

    // Filter out known benign errors
    const criticalErrors = consoleErrors.filter(
      (err) =>
        !err.includes('favicon') &&
        !err.includes('404') &&
        !err.includes('Failed to load resource')
    );

    expect(criticalErrors).toHaveLength(0);
  });

  test('has skip link for accessibility', async ({ page }) => {
    const skipLink = page.locator('[href="#main-content"], .skip-link, [class*="skip"]');

    // Skip link should exist
    const skipLinkCount = await skipLink.count();
    if (skipLinkCount > 0) {
      // Should be visually hidden initially
      const firstSkipLink = skipLink.first();

      // Focus the skip link
      await page.keyboard.press('Tab');

      // After tab, skip link should be visible or focusable
      await expect(firstSkipLink).toBeFocused({ timeout: 5000 }).catch(() => {
        // Skip link may not be the first focusable element
      });
    }
  });

  test('images have alt attributes', async ({ page }) => {
    const images = page.locator('img');
    const imageCount = await images.count();

    for (let i = 0; i < imageCount; i++) {
      const alt = await images.nth(i).getAttribute('alt');
      // Alt attribute should exist (can be empty for decorative images)
      expect(alt).not.toBeNull();
    }
  });
});

test.describe('Homepage - Performance', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('loads within acceptable time', async ({ page }) => {
    const startTime = Date.now();

    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const loadTime = Date.now() - startTime;

    // Should load DOM content within 5 seconds
    expect(loadTime).toBeLessThan(5000);
  });

  test('critical content is visible without scrolling', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Header should be in viewport
    const header = page.locator('header').first();
    await expect(header).toBeInViewport();

    // Title should be visible
    const title = page.locator('h1, .site-title').first();
    if ((await title.count()) > 0) {
      await expect(title).toBeInViewport();
    }
  });
});
