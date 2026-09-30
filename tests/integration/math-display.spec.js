import { expect, test } from '@playwright/test';

/**
 * How a display equation is set (#318). It was a bordered, shadowed card and
 * every one was numbered; by default it now stands on its own line with space
 * around it, its tools appear where the pointer or the focus is, and MathJax
 * numbers only the equations a text can refer to.
 *
 * This build is a plain site. For `display_style: card` the posts are given
 * the stylesheet such a site compiles (_test_pages/math-card.scss) and the
 * class its layout puts on <body>.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const posts = [
  '/2024/04/08/mathematical-proof-numbered-equations/',
  '/2024/04/06/research-paper-with-citations/'
];

async function open(page, path, style) {
  await page.goto(new URL(path, baseUrl).href, { waitUntil: 'load' });
  await page.waitForFunction(() => document.body.classList.contains('math-ready'));
  await expect(page.locator('.math-expression__toolbar').first()).toBeAttached();
  if (style === 'card') {
    await page.evaluate(async () => {
      const link = document.querySelector('link[rel="stylesheet"][href*="/assets/css/main"]');
      const loaded = new Promise((resolve) => link.addEventListener('load', resolve, { once: true }));
      // The integrity hash is main.css's, and would refuse the other file.
      link.removeAttribute('integrity');
      link.href = '/_test_pages/math-card.css';
      document.body.classList.add('math-card');
      await loaded;
    });
  }
}

/** Every typeset display equation of the page, measured. */
function measure(page) {
  return page.locator('.math-expression:has(> mjx-container)').evaluateAll((wrappers) =>
    wrappers.map((wrapper) => {
      const container = wrapper.querySelector(':scope > mjx-container');
      const style = getComputedStyle(wrapper);
      const inner = getComputedStyle(container);
      return {
        height: wrapper.getBoundingClientRect().height,
        content: container.getBoundingClientRect().height + parseFloat(inner.marginTop) + parseFloat(inner.marginBottom),
        margin: [parseFloat(style.marginTop), parseFloat(style.marginBottom)],
        padding: parseFloat(style.paddingTop) + parseFloat(style.paddingBottom),
        border: parseFloat(style.borderTopWidth),
        shadow: style.boxShadow,
        scrolls: wrapper.scrollHeight > wrapper.clientHeight
      };
    })
  );
}

/** Focuses the paragraph before the `index`th equation, so Tab reaches the equation next. */
async function focusBefore(page, index) {
  await page.locator('.math-expression').nth(index).evaluate((wrapper) => {
    const before = wrapper.previousElementSibling;
    before.setAttribute('tabindex', '-1');
    before.focus();
  });
}

test.describe('Display equations', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');
  test.use({ viewport: { width: 1280, height: 900 } });

  for (const path of posts) {
    test(`plain: an equation adds its height and its margins, nothing else (${path})`, async ({ page }) => {
      await open(page, path, 'plain');
      const equations = await measure(page);
      expect(equations.length).toBeGreaterThan(0);

      for (const equation of equations) {
        expect(equation.padding).toBe(0);
        expect(equation.border).toBe(0);
        expect(equation.shadow).toBe('none');
        expect(equation.height).toBeLessThanOrEqual(equation.content + 1);
        expect(equation.margin).toEqual([20, 20]);
        expect(equation.scrolls).toBe(false);
      }
    });

    test(`card: each equation keeps its frame (${path})`, async ({ page }) => {
      await open(page, path, 'card');
      const equations = await measure(page);
      expect(equations.length).toBeGreaterThan(0);

      // The demo opens dark, where the card has a border and no shadow.
      for (const equation of equations) {
        expect(equation.border).toBe(1);
        expect(equation.padding).toBeGreaterThan(50);
        expect(equation.height).toBeGreaterThan(equation.content + 50);
      }
    });
  }

  test('plain: the tools appear on hover and on focus, and the keyboard reaches them', async ({ page }) => {
    await open(page, posts[0], 'plain');
    // The display after "The sine basis satisfies", a paragraph with no math of its own.
    const equation = page.locator('.math-expression').nth(1);
    const toolbar = equation.locator('.math-expression__toolbar');
    await expect(toolbar).toHaveCSS('opacity', '0');

    await equation.hover();
    await expect(toolbar).toHaveCSS('opacity', '1');
    await page.mouse.move(0, 0);
    await expect(toolbar).toHaveCSS('opacity', '0');

    await focusBefore(page, 1);
    await page.keyboard.press('Tab');
    const expression = equation.locator('> mjx-container');
    await expect(expression).toBeFocused();
    await expect(toolbar).toHaveCSS('opacity', '1');
    await expect(expression).toHaveCSS('outline-style', 'solid');
    // The box it scrolls in leaves room for the ring at the sides.
    const room = await equation.evaluate((wrapper) => {
      const box = wrapper.getBoundingClientRect();
      const ring = wrapper.querySelector(':scope > mjx-container').getBoundingClientRect();
      return Math.min(ring.left - box.left, box.right - ring.right);
    });
    expect(room).toBeGreaterThanOrEqual(4);

    await page.keyboard.press('Tab');
    await expect(equation.locator('[data-math-copy]')).toBeFocused();
    await expect(equation.locator('[data-math-copy]')).toHaveCSS('outline-style', 'solid');
    await expect(toolbar).toHaveCSS('opacity', '1');

    await page.keyboard.press('Tab');
    await expect(equation.locator('[data-math-edit]')).toBeFocused();
    await expect(toolbar).toHaveCSS('opacity', '1');
  });

  test('card: the tools are always in view, and the focus ring still shows', async ({ page }) => {
    await open(page, posts[0], 'card');
    const equation = page.locator('.math-expression').nth(1);
    await expect(equation.locator('.math-expression__toolbar')).toHaveCSS('opacity', '1');

    await focusBefore(page, 1);
    await page.keyboard.press('Tab');
    await expect(equation.locator('> mjx-container')).toBeFocused();
    await expect(equation.locator('> mjx-container')).toHaveCSS('outline-style', 'solid');
  });

  test.describe('on a touch screen', () => {
    test.use({ viewport: { width: 375, height: 800 }, hasTouch: true, isMobile: true });

    // A touch screen has no hover; a tap focuses the equation, which shows its
    // tools. `x = 1` holds none of the toggles MathJax adds to collapse a long
    // expression, which re-render it when tapped and so drop the focus.
    test('plain: a tap on an equation shows its tools', async ({ page }) => {
      await open(page, '/test-regressions/math-numbering/', 'plain');
      const equation = page.locator('.math-expression').first();
      const expression = equation.locator('> mjx-container');
      const toolbar = equation.locator('.math-expression__toolbar');
      await expect(toolbar).toHaveCSS('opacity', '0');

      await expression.tap();
      await expect(expression).toBeFocused();
      await expect(toolbar).toHaveCSS('opacity', '1');
    });
  });

  test('ams: a labelled equation is numbered, $$x = 1$$ is not, and \\eqref resolves', async ({ page }) => {
    await open(page, '/test-regressions/math-numbering/', 'plain');

    const numbers = await page.locator('.math-expression').evaluateAll((wrappers) =>
      wrappers.map((wrapper) => wrapper.dataset.equationNumber || '')
    );
    // x = 1, the $$ display with a \label, the align's first line, equation*.
    expect(numbers).toEqual(['', '(1)', '(2)', '']);

    const references = page.locator('.math-reference-link');
    await expect(references).toHaveText(['Equation (1)', 'Equation (2)']);
    const resolved = await references.evaluateAll((links) =>
      links.map((link) => Boolean(document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1)))))
    );
    expect(resolved).toEqual([true, true]);
    await expect(page.locator('mjx-container').filter({ hasText: '???' })).toHaveCount(0);
  });
});
