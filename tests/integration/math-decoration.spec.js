import { expect, test } from '@playwright/test';

/**
 * What the math toolkit adds to a typeset page. None of it reached a real
 * article before #329: MathJax hands its expressions over as a linked list,
 * `decorateExisting` called `forEach` on it, and the exception was swallowed
 * by the `catch` around initialization. The unit tests mocked the list as an
 * array, which is the one shape it never has, so only a browser catches this.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const article = '/2024/04/08/mathematical-proof-numbered-equations/';

test.describe('Math decoration', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.goto(new URL(article, baseUrl).href, { waitUntil: 'load' });
    await page.waitForFunction(() => document.body.classList.contains('math-ready'));
    await expect(page.locator('.math-expression__toolbar').first()).toBeVisible();
  });

  test('every typeset expression is named for a screen reader', async ({ page }) => {
    // Every expression except the references MathJax draws as a link, which
    // are named by the link exposeReferenceLinks puts after them.
    const expressions = page.locator('mjx-container:not(:has(a[href]))');
    const named = page.locator('mjx-container[role="math"][aria-label]:not(:has(a[href]))');
    const total = await expressions.count();
    expect(total).toBeGreaterThan(0);
    await expect(named).toHaveCount(total);
  });

  test('a display equation carries the copy and edit tools', async ({ page }) => {
    const equation = page.locator('.math-expression').first();
    await expect(equation.locator('[data-math-copy]')).toHaveCount(1);
    await expect(equation.locator('[data-math-edit]')).toHaveCount(1);
  });

  test('an equation is numbered once, by MathJax', async ({ page }) => {
    // MathJax draws its own number when `tex.tags` is on, and the theme ships
    // `tags: 'all'`. A badge of the toolkit's own would be the same number a
    // second time, in the corner of the card.
    await expect(page.locator('.math-expression__number')).toHaveCount(0);

    const numbers = await page.locator('.math-expression').evaluateAll((nodes) =>
      nodes.map((node) => node.dataset.equationNumber)
    );
    expect(numbers).toEqual(['(1)', '(2)']);
  });

  test('the tools sit beside the expression, not inside it', async ({ page }) => {
    // A role="math" element holding the copy and edit buttons, or holding the
    // link MathJax draws for \eqref, is a nested interactive control.
    const wrapper = page.locator('.math-expression').first();
    await expect(wrapper).not.toHaveAttribute('role', 'math');
    await expect(wrapper.locator('> mjx-container[role="math"]')).toHaveCount(1);

    const reference = page.locator('mjx-container:has(a[href])').first();
    await expect(reference).not.toHaveAttribute('tabindex', '0');
  });

  test('a reference reaches the equation it names', async ({ page }) => {
    const reference = page.locator('.math-reference-link').first();
    await expect(reference).toHaveText(/Equation \(1\)/);

    const resolved = await reference.evaluate((link) =>
      Boolean(document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1))))
    );
    expect(resolved).toBe(true);
  });
});
