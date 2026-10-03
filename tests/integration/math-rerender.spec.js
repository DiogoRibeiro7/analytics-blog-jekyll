import { expect, test } from '@playwright/test';

/**
 * What happens to a typeset expression after the first render. MathJax's
 * collapsible setting wrapped parts of a formula in toggles, so a click meant
 * to select one collapsed part of it to ◂…▸; and MathJax drew it again into a
 * new container, without the tab stop, the role and the label the toolkit had
 * given the first, while the focus fell to the page (#412). MathJax draws
 * every expression again whenever a reader changes a setting in its menu.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const article = '/2024/04/08/mathematical-proof-numbered-equations/';

// The expressions the toolkit names, and how many of them still are.
const labelled = (page) =>
  page.evaluate(() => {
    const expressions = [...document.querySelectorAll('mjx-container')].filter((node) => !node.querySelector('a[href]'));
    const named = expressions.filter(
      (node) =>
        node.getAttribute('tabindex') === '0' && node.getAttribute('role') === 'math' && node.getAttribute('aria-label')
    );
    return { total: expressions.length, named: named.length };
  });

const focusedLabel = (page) =>
  page.evaluate(() => {
    const active = document.activeElement;
    return active && active.tagName === 'MJX-CONTAINER' ? active.getAttribute('aria-label') : null;
  });

async function open(page) {
  await page.goto(new URL(article, baseUrl).href, { waitUntil: 'load' });
  await page.waitForFunction(() => document.body.classList.contains('math-ready'));
  await expect(page.locator('mjx-container[role="math"]').first()).toBeVisible();
}

test.describe('Math after the first render', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('a click on an expression collapses nothing and keeps its name and focus', async ({ page }) => {
    await open(page);
    await expect(page.locator('mjx-maction')).toHaveCount(0);
    const before = await labelled(page);

    const expression = page.locator('mjx-container[role="math"]').first();
    const label = await expression.getAttribute('aria-label');
    await expression.click();

    expect(await labelled(page)).toEqual(before);
    expect(await focusedLabel(page)).toBe(label);
  });

  test('every expression keeps its name, and the focused one its focus, when MathJax draws them again', async ({ page }) => {
    await open(page);
    const before = await labelled(page);
    const links = await page.locator('.math-reference-link').count();
    const expression = page.locator('mjx-container[role="math"]').nth(1);
    const label = await expression.getAttribute('aria-label');
    await expression.focus();

    // What a change in MathJax's menu does.
    await page.evaluate(() => window.MathJax.startup.document.rerender());

    await expect.poll(() => labelled(page)).toEqual(before);
    expect(await focusedLabel(page)).toBe(label);
    await expect(page.locator('.math-reference-link')).toHaveCount(links);
  });

  // A reader may turn collapsing back on in the menu, which MathJax saves.
  test('a part a reader collapses on purpose leaves the expression named and focused', async ({ page }) => {
    await page.addInitScript(() => {
      try {
        localStorage.setItem('MathJax-Menu-Settings', JSON.stringify({ collapsible: true }));
      } catch {
        // Without storage the setting stays off, and the test below has nothing to click.
      }
    });
    await open(page);
    const expression = page.locator('mjx-container[role="math"]:has(mjx-maction)').first();
    test.skip((await expression.count()) === 0, 'MathJax offered no collapsible part');
    const before = await labelled(page);
    const label = await expression.getAttribute('aria-label');
    await expression.focus();

    await expression.locator('mjx-maction').first().click();

    await expect.poll(() => labelled(page)).toEqual(before);
    expect(await focusedLabel(page)).toBe(label);
  });
});
