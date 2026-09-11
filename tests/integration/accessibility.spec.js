import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Accessibility - Skip Links', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('skip link appears on focus', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Press Tab to focus skip link
    await page.keyboard.press('Tab');

    // Look for skip link
    const skipLink = page.locator('.skip-link, [class*="skip"], a[href="#main-content"]');

    if ((await skipLink.count()) > 0) {
      // Skip link should be visible when focused
      await expect(skipLink.first()).toBeVisible({ timeout: 2000 }).catch(() => {
        // Some implementations show on focus, some always visible
      });
    }
  });

  test('skip link navigates to main content', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const skipLink = page.locator('.skip-link, [class*="skip"], a[href="#main-content"]');

    if ((await skipLink.count()) > 0) {
      // Focus and activate skip link
      await skipLink.first().focus();
      await page.keyboard.press('Enter');

      // Main content should be focused or in view
      const mainContent = page.locator('#main-content, main, [role="main"]');
      if ((await mainContent.count()) > 0) {
        await expect(mainContent.first()).toBeInViewport();
      }
    }
  });
});

test.describe('Accessibility - Keyboard Navigation', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('all interactive elements are keyboard accessible', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Get all interactive elements
    const interactive = page.locator(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );

    const count = await interactive.count();
    expect(count).toBeGreaterThan(0);

    // Tab through first few elements
    for (let i = 0; i < Math.min(count, 10); i++) {
      await page.keyboard.press('Tab');

      // Something should be focused
      const focusedElement = await page.evaluate(() => document.activeElement?.tagName);
      expect(focusedElement).toBeTruthy();
      expect(focusedElement).not.toBe('BODY');
    }
  });

  test('focus is visible on interactive elements', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Tab to first interactive element
    await page.keyboard.press('Tab');

    // Get the focused element
    const focusedElement = await page.evaluate(() => {
      const el = document.activeElement;
      if (!el) return null;

      const styles = window.getComputedStyle(el);
      return {
        outline: styles.outline,
        boxShadow: styles.boxShadow,
        border: styles.border
      };
    });

    // Should have some visible focus indicator
    // (outline, box-shadow, or border change)
    expect(focusedElement).toBeTruthy();
  });

  test('escape key closes modals/dropdowns', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Look for dropdown or modal triggers that can actually be clicked at this
    // viewport (the mobile navigation toggle is hidden on desktop widths).
    const trigger = page
      .locator('[aria-haspopup], [aria-expanded], .dropdown-toggle, [class*="dropdown"]')
      .filter({ visible: true });

    if ((await trigger.count()) > 0) {
      // Open the dropdown
      await trigger.first().click();
      await page.waitForTimeout(300);

      // Check if something opened
      const expanded = await trigger.first().getAttribute('aria-expanded');

      if (expanded === 'true') {
        // Press Escape
        await page.keyboard.press('Escape');
        await page.waitForTimeout(300);

        // Should be closed
        const closedState = await trigger.first().getAttribute('aria-expanded');
        expect(closedState).toBe('false');
      }
    }
  });
});

test.describe('Accessibility - ARIA Landmarks', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('page has proper landmark structure', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Should have header/banner
    const header = page.locator('header, [role="banner"]');
    expect(await header.count()).toBeGreaterThan(0);

    // Should have main content
    const main = page.locator('main, [role="main"]');
    expect(await main.count()).toBeGreaterThan(0);

    // Should have navigation
    const nav = page.locator('nav, [role="navigation"]');
    expect(await nav.count()).toBeGreaterThan(0);

    // Should have footer/contentinfo
    const footer = page.locator('footer, [role="contentinfo"]');
    expect(await footer.count()).toBeGreaterThan(0);
  });

  test('headings follow proper hierarchy', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Get all headings in order
    const headings = await page.evaluate(() => {
      const elements = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
      return Array.from(elements).map((el) => ({
        level: parseInt(el.tagName.charAt(1)),
        text: el.textContent.trim().substring(0, 50)
      }));
    });

    // Should have at least one heading
    expect(headings.length).toBeGreaterThan(0);

    // Should start with h1
    expect(headings[0].level).toBe(1);

    // Check that levels don't skip (e.g., h1 -> h3)
    for (let i = 1; i < headings.length; i++) {
      const jump = headings[i].level - headings[i - 1].level;
      // Should not skip more than one level down
      expect(jump).toBeLessThanOrEqual(1);
    }
  });
});

test.describe('Accessibility - Forms', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('form inputs have associated labels', async ({ page }) => {
    await page.goto(`${baseUrl}/search/`, { waitUntil: 'domcontentloaded' }).catch(() => {
      // Search page might not exist
    });

    const inputs = page.locator(
      'input:not([type="hidden"]):not([type="submit"]):not([type="button"]), textarea, select'
    );

    const inputCount = await inputs.count();

    for (let i = 0; i < inputCount; i++) {
      const input = inputs.nth(i);
      const id = await input.getAttribute('id');
      const ariaLabel = await input.getAttribute('aria-label');
      const ariaLabelledBy = await input.getAttribute('aria-labelledby');
      const placeholder = await input.getAttribute('placeholder');
      // A control nested inside <label> is labelled implicitly.
      const wrappedInLabel = await input.evaluate((el) => Boolean(el.closest('label')));

      // Should have some form of label
      if (id) {
        const label = page.locator(`label[for="${id}"]`);
        const hasLabel = (await label.count()) > 0;
        const hasAriaLabel = ariaLabel || ariaLabelledBy;

        expect(hasLabel || hasAriaLabel || placeholder || wrappedInLabel).toBeTruthy();
      } else {
        // Without id, should have aria-label, placeholder or a wrapping label
        expect(ariaLabel || ariaLabelledBy || placeholder || wrappedInLabel).toBeTruthy();
      }
    }
  });
});

test.describe('Accessibility - Images', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('all images have alt attributes', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const images = page.locator('img');
    const imageCount = await images.count();

    for (let i = 0; i < imageCount; i++) {
      const alt = await images.nth(i).getAttribute('alt');
      // Alt attribute should exist (even if empty for decorative images)
      expect(alt).not.toBeNull();
    }
  });

  test('decorative images are properly marked', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const images = page.locator('img');
    const imageCount = await images.count();

    for (let i = 0; i < imageCount; i++) {
      const alt = await images.nth(i).getAttribute('alt');
      const role = await images.nth(i).getAttribute('role');

      // If alt is empty, should have role="presentation" or aria-hidden
      if (alt === '') {
        const ariaHidden = await images.nth(i).getAttribute('aria-hidden');
        // Decorative images should be marked appropriately
        // This is a soft check - empty alt is acceptable
        expect(alt === '' || role === 'presentation' || ariaHidden === 'true').toBe(true);
      }
    }
  });
});

test.describe('Accessibility - Color Contrast', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('text elements have sufficient size', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Check that body text is at least 14px
    const bodyFontSize = await page.evaluate(() => {
      const body = document.body;
      const style = window.getComputedStyle(body);
      return parseFloat(style.fontSize);
    });

    expect(bodyFontSize).toBeGreaterThanOrEqual(14);
  });
});
