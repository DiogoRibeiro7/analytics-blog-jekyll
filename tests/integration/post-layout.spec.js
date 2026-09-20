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

  test('narrow articles contain wide content and preserve image proportions', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(new URL('/test-regressions/rendering/', baseUrl).href);
    await expect(page.locator('.math-expression-inline mjx-container').first()).toBeVisible();
    await expect(page.locator('.math-expression mjx-container').first()).toBeVisible();
    const measurements = await page.evaluate(() => {
      const article = document.querySelector('.post-content');
      const img = article.querySelector('img');
      const box = img.getBoundingClientRect();
      const table = article.querySelector('.content-table');
      return {
        width: document.documentElement.scrollWidth,
        viewport: window.innerWidth,
        ratio: box.width / box.height,
        naturalRatio: img.naturalWidth / img.naturalHeight,
        tableOverflow: table.scrollWidth > table.clientWidth,
        tableTabindex: table.tabIndex,
        gutter: parseFloat(getComputedStyle(article.querySelector('.rouge-gutter')).paddingRight),
        stickyNotes: [...document.querySelectorAll('.content-provenance, .revision-notice, .author-bio')]
          .filter((node) => getComputedStyle(node).position === 'sticky').length,
      };
    });
    expect(measurements.width).toBeLessThanOrEqual(measurements.viewport);
    expect(measurements.ratio).toBeCloseTo(measurements.naturalRatio, 2);
    expect(measurements.tableOverflow).toBe(true);
    expect(measurements.tableTabindex).toBe(0);
    expect(measurements.gutter).toBeGreaterThan(0);
    expect(measurements.stickyNotes).toBe(0);
  });

  test('print retains visualization tables and live content without code gutters', async ({ page }) => {
    await page.goto(new URL('/test-regressions/rendering/', baseUrl).href);
    await page.emulateMedia({ media: 'print' });
    await expect(page.locator('.viz-table-wrapper table')).toBeVisible();
    await expect(page.locator('.project-case__github-stats')).toBeVisible();
    await expect(page.locator('.rouge-gutter').first()).toBeHidden();
  });
});
