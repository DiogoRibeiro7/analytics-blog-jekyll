import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

const pages = [
  {
    name: 'post table of contents',
    path: '/2024/04/05/sql-optimization-guide/',
    link: '.enhanced-toc a[href^="#"]',
  },
  {
    name: 'package navigation',
    path: '/packages/statflow/',
    link: '.package-nav__link[href^="#"]',
  },
];

// An instant scroll has moved the page by the time click() returns. A smooth
// one runs on later frames, so in the same task the page has not moved yet.
function clickLastLink(page, selector) {
  return page.evaluate((linkSelector) => {
    const links = document.querySelectorAll(linkSelector);
    const link = links[links.length - 1];
    const before = window.scrollY;
    link.click();
    return { before, after: window.scrollY };
  }, selector);
}

test.describe('Reduced motion', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the page scrolls smoothly only without a reduced-motion preference', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(new URL('/2024/04/05/sql-optimization-guide/', baseUrl).href, { waitUntil: 'load' });
    const rootBehavior = () => page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior);
    expect(await rootBehavior()).toBe('auto');

    await page.emulateMedia({ reducedMotion: 'no-preference' });
    expect(await rootBehavior()).toBe('smooth');
  });

  for (const { name, path, link } of pages) {
    test(`${name} jumps to its target when reduced motion is requested`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.goto(new URL(path, baseUrl).href, { waitUntil: 'load' });
      await expect(page.locator(link).first()).toBeAttached();

      const { before, after } = await clickLastLink(page, link);
      expect(after).toBeGreaterThan(before);
    });

    test(`${name} scrolls smoothly without a reduced-motion preference`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: 'no-preference' });
      await page.goto(new URL(path, baseUrl).href, { waitUntil: 'load' });
      await expect(page.locator(link).first()).toBeAttached();

      const { before, after } = await clickLastLink(page, link);
      expect(after).toBe(before);
      await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(before);
    });
  }
});
