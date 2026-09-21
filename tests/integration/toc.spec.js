import { expect, test } from '@playwright/test';

/**
 * The table of contents. Reaching a heading is the browser's own navigation:
 * the script that used to intercept it cancelled the default and then threw on
 * any id that starts with a digit, which is what a numbered section heading
 * produces (#330).
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const article = '/test-regressions/toc-numbered/';

test.describe('Table of contents', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');
  test.use({ viewport: { width: 1280, height: 900 } });

  test.beforeEach(async ({ page }) => {
    await page.goto(new URL(article, baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('nav.enhanced-toc')).toHaveCount(1);
  });

  test('an entry for a numbered heading reaches its section', async ({ page }) => {
    const heading = page.locator('[id="2-method"]');
    await expect(heading).toHaveCount(1);

    await page.click('.enhanced-toc__content a[href="#2-method"]');

    await expect(page).toHaveURL(/#2-method$/);
    await expect(heading).toBeInViewport();
    // The sticky header must not be covering it.
    const box = await heading.boundingBox();
    expect(box.y).toBeGreaterThan(0);
  });

  test('the keyboard carries on from the section, not from the contents', async ({ page }) => {
    // Fragment navigation moves the point the next Tab starts from. The
    // handler this replaced cancelled the navigation, so Tab went back to
    // wherever the contents left off and a keyboard reader never arrived.
    await page.click('.enhanced-toc__content a[href="#3-results"]');
    await page.keyboard.press('Tab');

    const focused = await page.evaluate(() => ({
      tag: document.activeElement?.tagName,
      href: document.activeElement?.getAttribute('href')
    }));
    expect(focused).toEqual({ tag: 'A', href: 'https://example.org/' });
  });

  test('the section being read is marked for assistive technology too', async ({ page }) => {
    await page.locator('[id="2-method"]').evaluate((node) => node.scrollIntoView());
    await page.waitForFunction(() =>
      document.querySelector('.enhanced-toc__content a[aria-current="location"]') !== null
    );

    const current = page.locator('.enhanced-toc__content a[aria-current="location"]');
    await expect(current).toHaveCount(1);
    await expect(current).toHaveClass(/is-active/);
  });

  test('the progress indicator reports a number', async ({ page }) => {
    await page.mouse.wheel(0, 2000);
    await page.waitForTimeout(200);

    const percent = await page.locator('[data-progress-percent]').textContent();
    expect(percent).toMatch(/^\d+$/);
    const width = await page.locator('[data-toc-progress]').evaluate((node) => node.style.width);
    expect(width).toMatch(/^\d+%$/);
  });
});
