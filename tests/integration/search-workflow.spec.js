import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Search workflow', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('supports debounced, accessible searching end-to-end', async ({ page }) => {
    await page.route('**/search.json', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 600));
      await route.continue();
    });

    await page.goto(`${baseUrl}/search/`, { waitUntil: 'networkidle' });

    await page.waitForFunction(
      () => document?.body?.dataset?.featureSearchState === 'ready',
      { timeout: 15000 }
    );

    const input = page.locator('[data-search-input]');
    const loading = page.locator('[data-search-loading]');
    const resultsList = page.locator('[data-search-results]');
    const liveCount = page.locator('[data-search-live="count"]');
    const liveSelection = page.locator('[data-search-live="selection"]');
    const liveStatus = page.locator('[data-search-live="status"]');

    await expect(input).toBeVisible();
    await expect(loading).toBeHidden();

    await input.fill('python');
    await page.waitForTimeout(350);
    await expect(loading).toBeVisible();

    const resultItems = resultsList.locator('.search-result');
    await expect(resultItems.first()).toBeVisible({ timeout: 15000 });

    await expect(liveCount).toContainText(/result/i);
    await expect(liveCount).not.toHaveAttribute('hidden', '');

    await input.focus();
    await page.keyboard.press('ArrowDown');

    // The arrows move real focus into the list. They used to move
    // aria-activedescendant around a listbox whose options held links, which
    // meant a screen reader in browse mode could reach none of them (#365).
    const activeResult = resultsList.locator('.search-result.is-active').first();
    await expect(activeResult).toBeVisible();
    await expect(activeResult.locator('[data-result-link]')).toBeFocused();
    expect(await input.getAttribute('aria-activedescendant')).toBeNull();
    await expect(liveSelection).toContainText(/Result 1/i);

    const initialUrl = page.url();
    await Promise.all([
      page.waitForNavigation({ url: (url) => url !== initialUrl }),
      page.keyboard.press('Enter')
    ]);
    await expect(page).not.toHaveURL(initialUrl);

    await page.goBack({ waitUntil: 'domcontentloaded' });

    await input.fill('python');
    await page.waitForTimeout(350);
    await expect(resultsList.locator('.search-result').first()).toBeVisible();

    await input.focus();
    await page.keyboard.press('Escape');

    await expect(liveStatus).toContainText(/cleared/i);
    await expect(input).toHaveValue('');
    await expect(resultsList.locator('.search-result')).toHaveCount(0, { timeout: 5000 });
  });

  // A list of cards with links in them is not a listbox, and saying it was one
  // hid everything inside each card from assistive technology (#365).
  test('a result is an ordinary list item whose links can be reached', async ({ page }) => {
    await page.goto(`${baseUrl}/search/`, { waitUntil: 'networkidle' });
    await page.waitForFunction(() => document?.body?.dataset?.featureSearchState === 'ready', { timeout: 15000 });

    await page.locator('[data-search-input]').fill('reproducibility');
    const first = page.locator('.search-result').first();
    await expect(first).toBeVisible({ timeout: 15000 });

    const roles = await page.evaluate(() => ({
      list: document.querySelector('[data-search-results]').getAttribute('role'),
      item: document.querySelector('.search-result').getAttribute('role'),
      tabindex: document.querySelector('.search-result').getAttribute('tabindex'),
    }));
    expect(roles).toEqual({ list: null, item: null, tabindex: null });

    // Tab alone reaches the title, which is what role="option" prevented.
    await page.locator('[data-search-input]').focus();
    await page.keyboard.press('ArrowDown');
    await expect(first.locator('[data-result-link]')).toBeFocused();

    // Escape from the list comes back to the query rather than clearing it.
    await page.keyboard.press('Escape');
    await expect(page.locator('[data-search-input]')).toBeFocused();
    await expect(page.locator('[data-search-input]')).toHaveValue('reproducibility');
  });

  // A result used to point at the top of a 6,000-word article. It now lists
  // the sections the words were in, and following one has to land on the
  // heading rather than the top of the page (#336).
  test('a result links to the section the words were in', async ({ page }) => {
    await page.goto(`${baseUrl}/search/`, { waitUntil: 'networkidle' });
    await page.waitForFunction(() => document?.body?.dataset?.featureSearchState === 'ready', { timeout: 15000 });

    await page.locator('[data-search-input]').fill('reproducibility');
    await expect(page.locator('[data-result-sections]:not([hidden])').first()).toBeVisible({ timeout: 15000 });

    // A heading with no id of its own links to the page, which is right but is
    // not what this is about.
    const link = page.locator('[data-result-sections]:not([hidden]) a[href*="#"]').first();
    await expect(link).toBeVisible();
    const href = await link.getAttribute('href');
    const anchor = href.slice(href.indexOf('#') + 1);

    await link.click();
    await page.waitForLoadState('load');
    await expect(page).toHaveURL(new RegExp(`#${anchor}$`));

    // getElementById, not querySelector: kramdown gives "1. Introduction" the
    // id "1-introduction", which is not a valid CSS identifier (#330). The
    // theme sets scroll-behavior: smooth, so the jump is animated and is not
    // over when the load event fires.
    await page.waitForFunction(
      (id) => {
        const element = document.getElementById(decodeURIComponent(id));
        if (!element) {
          return false;
        }
        const top = element.getBoundingClientRect().top;
        return top >= -2 && top < window.innerHeight;
      },
      anchor,
      { timeout: 15000 }
    );

    const tag = await page.evaluate((id) => document.getElementById(decodeURIComponent(id)).tagName, anchor);
    expect(['H2', 'H3']).toContain(tag);
  });
});
