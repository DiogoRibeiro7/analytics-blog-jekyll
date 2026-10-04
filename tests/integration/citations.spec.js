import { expect, test } from '@playwright/test';

/**
 * Citations from a BibTeX file (#289), on the demo's research post: each
 * marker reaches its entry, each entry reaches back to where it is cited, and
 * the printed list keeps every address.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const post = '/2024/04/06/research-paper-with-citations/';

test.describe('Citations', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
  });

  test('the markers are numbered in citation order and each reaches its entry', async ({ page }) => {
    const markers = page.locator('.post-content .datalog-cite');
    await expect(markers).toHaveText(['[1]', '[2]', '[3, 4]', '[1]', '[4, sec. 7]']);

    await markers.first().locator('a').click();
    await expect(page).toHaveURL(/#cite-li2010$/);
    await expect(page.locator('#cite-li2010')).toBeInViewport();
  });

  test('an entry leads back to each place it is cited', async ({ page }) => {
    const back = page.locator('#cite-li2010 .datalog-bibliography__back a');
    await expect(back).toHaveCount(2);

    await back.nth(1).click();
    await expect(page).toHaveURL(/#cite-ref-li2010-2$/);
    await expect(page.locator('#cite-ref-li2010-2')).toBeInViewport();
  });

  test('printed, the list keeps each address and drops the links back', async ({ page }) => {
    await page.emulateMedia({ media: 'print' });
    await expect(page.locator('#cite-russo2018')).toContainText('https://doi.org/10.1561/2200000070');
    await expect(page.locator('#cite-russo2018 .datalog-bibliography__back')).toBeHidden();
  });
});
