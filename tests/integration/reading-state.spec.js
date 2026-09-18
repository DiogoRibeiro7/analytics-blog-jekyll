import { expect, test } from '@playwright/test';

/**
 * Local reading state (#260): a bookmark that survives a reload, a reading
 * position offered back on return, a highlight made from the keyboard that
 * is painted again on the next visit and can be removed, the saved-articles
 * page, and a browser that blocks storage.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const post = '/2024/04/05/sql-optimization-guide/';

async function selectText(page, text) {
  return page.evaluate((needle) => {
    const walker = document.createTreeWalker(document.querySelector('.post-content'), NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const at = node.data.indexOf(needle);
      if (at !== -1) {
        const range = document.createRange();
        range.setStart(node, at);
        range.setEnd(node, at + needle.length);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        return true;
      }
    }
    return false;
  }, text);
}

test.describe('Reading state', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('a bookmark is kept across visits and listed on the saved page', async ({ page }) => {
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
    const bookmark = page.locator('[data-bookmark-toggle]');
    await expect(bookmark).toHaveAttribute('aria-pressed', 'false');

    await bookmark.click();
    await expect(bookmark).toHaveAttribute('aria-pressed', 'true');
    await expect(bookmark).toHaveText(/Saved/);

    await page.reload({ waitUntil: 'load' });
    await expect(page.locator('[data-bookmark-toggle]')).toHaveAttribute('aria-pressed', 'true');

    await page.goto(new URL('/saved/', baseUrl).href, { waitUntil: 'load' });
    const item = page.locator('[data-reading-list-items] li');
    await expect(item).toHaveCount(1);
    await expect(item.locator('a')).toHaveAttribute('href', post);
    await expect(item.locator('.reading-list__meta')).toContainText('Saved');
  });

  test('a reading position is saved and offered back', async ({ page }) => {
    await page.setViewportSize({ width: 1000, height: 500 });
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('[data-reading-resume]')).toBeHidden();

    await page.evaluate(() => {
      const content = document.querySelector('.post-content');
      const rect = content.getBoundingClientRect();
      window.scrollTo(0, rect.top + window.scrollY + rect.height * 0.5);
    });
    await page.waitForTimeout(1500);
    const saved = await page.evaluate((url) => JSON.parse(localStorage.getItem(`datalog-reading:${url}`)), post);
    expect(saved.progress.ratio).toBeGreaterThan(0.3);

    await page.reload({ waitUntil: 'load' });
    const resume = page.locator('[data-reading-resume]');
    await expect(resume).toBeVisible();
    await expect(resume).toContainText('% read');

    await resume.locator('[data-reading-resume-go]').click();
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(100);
    await expect(resume).toBeHidden();
  });

  test('a highlight made from the keyboard is painted again on the next visit and can be removed', async ({ page }) => {
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
    expect(await selectText(page, 'Materialize the 90-day window')).toBe(true);

    await page.keyboard.press('Alt+Shift+H');

    const note = page.locator('.reading-note');
    await expect(note).toHaveCount(1);
    await expect(note.locator('[data-annotation-quote]')).toHaveText('Materialize the 90-day window');
    await expect(note.locator('[data-annotation-section]')).toHaveText('Optimization checklist');
    expect(await page.evaluate(() => CSS.highlights.get('datalog-annotation').size)).toBe(1);

    await page.reload({ waitUntil: 'load' });
    await expect(page.locator('.reading-note')).toHaveCount(1);
    await expect.poll(() => page.evaluate(() => CSS.highlights.get('datalog-annotation')?.size)).toBe(1);

    await page.locator('[data-annotation-remove]').click();
    await expect(page.locator('.reading-note')).toHaveCount(0);
    expect(await page.evaluate(() => CSS.highlights.get('datalog-annotation').size)).toBe(0);
  });

  test('a browser that blocks storage sees a message, disabled controls and no errors', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.addInitScript(() => {
      Object.defineProperty(window, 'localStorage', {
        get() {
          throw new Error('blocked');
        },
      });
    });
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });

    await expect(page.locator('[data-reading-unavailable]')).toBeVisible();
    await expect(page.locator('[data-bookmark-toggle]')).toBeDisabled();
    await expect(page.locator('[data-reading-export]')).toBeDisabled();
    await expect(page.locator('.post-content')).toBeVisible();
    expect(errors).toEqual([]);
  });
});
