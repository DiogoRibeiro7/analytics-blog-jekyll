import { expect, test } from '@playwright/test';

/**
 * A post with a table of contents has two columns from the large breakpoint:
 * 14rem for the contents, the rest for the article. A post without one, no
 * headings or `toc: false`, used to be laid out in the 14rem column.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Post layout', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');
  test.use({ viewport: { width: 1280, height: 900 } });

  test('an article without a table of contents spans the wrapper', async ({ page }) => {
    await page.goto(new URL('/2024/01/01/introducing-datalog/', baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('.enhanced-toc')).toHaveCount(0);

    const wrapper = await page.locator('.post-body-wrapper').boundingBox();
    const content = await page.locator('.post-content').boundingBox();
    expect(content.width).toBeGreaterThan(500);
    expect(Math.round(content.width)).toBe(Math.round(wrapper.width));
  });

  test('an article with one keeps the two columns, the contents a navigation landmark', async ({ page }) => {
    await page.goto(new URL('/2024/04/05/sql-optimization-guide/', baseUrl).href, { waitUntil: 'load' });
    const toc = page.locator('nav.enhanced-toc[role="doc-toc"]');
    await expect(toc).toHaveCount(1);

    const contents = await toc.boundingBox();
    const content = await page.locator('.post-content').boundingBox();
    expect(Math.round(contents.width)).toBe(224);
    expect(content.x).toBeGreaterThan(contents.x + contents.width);
  });
});
