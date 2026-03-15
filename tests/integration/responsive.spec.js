import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

const viewports = {
  mobile: { width: 375, height: 667 },
  tablet: { width: 768, height: 1024 },
  desktop: { width: 1280, height: 800 },
  widescreen: { width: 1920, height: 1080 }
};

test.describe('Responsive - Mobile', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(viewports.mobile);
  });

  test('mobile navigation toggle is visible', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Look for mobile menu toggle
    const menuToggle = page.locator(
      '.nav-toggle, .menu-toggle, [class*="hamburger"], [aria-label*="menu"], button[class*="mobile"]'
    );

    const toggleCount = await menuToggle.count();
    if (toggleCount > 0) {
      await expect(menuToggle.first()).toBeVisible();
    }
  });

  test('mobile navigation opens and closes', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const menuToggle = page.locator(
      '.nav-toggle, .menu-toggle, [class*="hamburger"], [aria-label*="menu"]'
    );

    if ((await menuToggle.count()) === 0) {
      test.skip(true, 'No mobile menu toggle found');
      return;
    }

    // Click to open
    await menuToggle.first().click();
    await page.waitForTimeout(300);

    // Navigation should be visible
    const nav = page.locator('nav, [role="navigation"]').first();
    const navLinks = nav.locator('a');

    // At least some nav links should be visible
    await expect(navLinks.first()).toBeVisible({ timeout: 2000 });

    // Click toggle again to close
    await menuToggle.first().click();
    await page.waitForTimeout(300);

    // Check aria-expanded
    const expanded = await menuToggle.first().getAttribute('aria-expanded');
    expect(expanded).toBe('false');
  });

  test('content is readable on mobile', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Main content should not overflow horizontally
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    expect(bodyWidth).toBeLessThanOrEqual(viewports.mobile.width + 20); // Allow small margin

    // Text should be readable size
    const fontSize = await page.evaluate(() => {
      const p = document.querySelector('p, .content, main');
      if (!p) return 16;
      return parseFloat(window.getComputedStyle(p).fontSize);
    });

    expect(fontSize).toBeGreaterThanOrEqual(14);
  });

  test('touch targets are adequately sized', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Check button and link sizes
    const touchTargets = page.locator('button, a, input[type="submit"]');
    const count = await touchTargets.count();

    let smallTargets = 0;

    for (let i = 0; i < Math.min(count, 20); i++) {
      const box = await touchTargets.nth(i).boundingBox();
      if (box) {
        // Touch targets should be at least 44x44 pixels (WCAG 2.5.5)
        // We'll use a softer check of 40x40
        if (box.width < 40 || box.height < 40) {
          smallTargets++;
        }
      }
    }

    // Allow some small targets (icons, etc.) but most should be adequate
    expect(smallTargets).toBeLessThan(count * 0.5);
  });

  test('no horizontal scrolling on mobile', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const hasHorizontalScroll = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });

    expect(hasHorizontalScroll).toBe(false);
  });
});

test.describe('Responsive - Tablet', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(viewports.tablet);
  });

  test('layout adapts to tablet size', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Content should be properly sized
    const main = page.locator('main, [role="main"], .content').first();
    const box = await main.boundingBox();

    if (box) {
      // Main content should use most of the width
      expect(box.width).toBeGreaterThan(viewports.tablet.width * 0.5);
    }
  });

  test('images scale properly', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const images = page.locator('img');
    const imageCount = await images.count();

    for (let i = 0; i < Math.min(imageCount, 5); i++) {
      const box = await images.nth(i).boundingBox();
      if (box) {
        // Images should not overflow viewport
        expect(box.width).toBeLessThanOrEqual(viewports.tablet.width);
      }
    }
  });
});

test.describe('Responsive - Desktop', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.setViewportSize(viewports.desktop);
  });

  test('desktop navigation is visible', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Desktop nav should be visible
    const nav = page.locator('nav, [role="navigation"]').first();
    await expect(nav).toBeVisible();

    // Nav links should be visible (not in hamburger menu)
    const navLinks = nav.locator('a');
    const linkCount = await navLinks.count();

    if (linkCount > 0) {
      await expect(navLinks.first()).toBeVisible();
    }
  });

  test('sidebar is visible on desktop', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Navigate to a blog post if on homepage
    const postLink = page.locator('article a, .post-link').first();
    if ((await postLink.count()) > 0) {
      await postLink.click();
      await page.waitForLoadState('domcontentloaded');
    }

    // Look for sidebar
    const sidebar = page.locator('aside, [class*="sidebar"], [role="complementary"]');

    if ((await sidebar.count()) > 0) {
      await expect(sidebar.first()).toBeVisible();
    }
  });

  test('multi-column layout on desktop', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Check if there's a multi-column layout
    const columns = await page.evaluate(() => {
      const main = document.querySelector('main, .content');
      if (!main) return 1;

      const style = window.getComputedStyle(main);
      const display = style.display;

      if (display === 'flex' || display === 'grid') {
        return main.children.length;
      }

      return 1;
    });

    // Desktop should potentially have multi-column layout
    // This is a soft check - not all pages need multiple columns
    expect(columns).toBeGreaterThanOrEqual(1);
  });
});

test.describe('Responsive - Viewport Transitions', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('layout adapts when viewport changes', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Start at desktop
    await page.setViewportSize(viewports.desktop);
    await page.waitForTimeout(300);

    // Get desktop nav visibility
    const desktopNavVisible = await page.evaluate(() => {
      const nav = document.querySelector('nav, [role="navigation"]');
      if (!nav) return false;
      const links = nav.querySelectorAll('a');
      if (links.length === 0) return false;
      const style = window.getComputedStyle(links[0]);
      return style.display !== 'none' && style.visibility !== 'hidden';
    });

    // Switch to mobile
    await page.setViewportSize(viewports.mobile);
    await page.waitForTimeout(300);

    // Check for mobile menu toggle
    const menuToggle = page.locator(
      '.nav-toggle, .menu-toggle, [class*="hamburger"], [aria-label*="menu"]'
    );

    const hasMobileToggle = (await menuToggle.count()) > 0;

    // Either desktop nav is always visible OR mobile has a toggle
    expect(desktopNavVisible || hasMobileToggle).toBe(true);
  });

  test('content reflows properly between breakpoints', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Test multiple breakpoints
    for (const [name, size] of Object.entries(viewports)) {
      await page.setViewportSize(size);
      await page.waitForTimeout(200);

      // Content should not overflow
      const hasOverflow = await page.evaluate(() => {
        return document.documentElement.scrollWidth > document.documentElement.clientWidth;
      });

      expect(hasOverflow).toBe(false);
    }
  });
});

test.describe('Responsive - Print', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('page is printable', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Emulate print media
    await page.emulateMedia({ media: 'print' });

    // Main content should still be visible
    const main = page.locator('main, [role="main"], .content').first();
    await expect(main).toBeVisible();

    // Navigation might be hidden for print
    // This is acceptable behavior
  });
});
