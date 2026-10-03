import { expect, test } from '@playwright/test';

/**
 * The notebook page's text against what it sits on, in both themes. axe leaves
 * the whole header undecided (its decorative ::after gradient hides the
 * background from it), and in dark mode the header's dates, the sidebar's
 * counts and an output's warning were dark grey on a dark panel: 2.1:1.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const notebook = '/notebooks/sample-analysis/';

// The demo notebook keeps no outputs, so the test adds the ones the converter
// writes (a text and an HTML output), and the warning assets/js/notebook.js
// puts in a chart it can't draw, with their class names.
const OUTPUTS = `
  <div class="notebook-cell__outputs">
    <div class="notebook-output notebook-output--text"><pre>   feature   value
0     0.00   0.497</pre></div>
    <div class="notebook-output notebook-output--html"><table><tr><th>feature</th><td>0.25</td></tr></table></div>
    <div class="notebook-output notebook-output--html"><div class="notebook-output-plotly"><p class="notebook-output__warning">Plotly figure could not be rendered. Open in Binder or Colab to interact.</p></div></div>
  </div>`;

// Each element with text of its own, its colour composited over the layers of
// background under it, and the contrast that leaves.
const measure = () => {
  const parse = (value) => {
    const match = /rgba?\(([^)]+)\)/.exec(value);
    if (!match) {
      return null;
    }
    const [red, green, blue, alpha = 1] = match[1]
      .split(/[\s,/]+/)
      .filter(Boolean)
      .map(Number);
    return { red, green, blue, alpha };
  };
  const over = (top, bottom) => ({
    red: top.red * top.alpha + bottom.red * (1 - top.alpha),
    green: top.green * top.alpha + bottom.green * (1 - top.alpha),
    blue: top.blue * top.alpha + bottom.blue * (1 - top.alpha),
    alpha: 1,
  });
  const backdrop = (element) => {
    const layers = [];
    for (let node = element; node; node = node.parentElement) {
      const colour = parse(getComputedStyle(node).backgroundColor);
      if (colour && colour.alpha > 0) {
        layers.push(colour);
        if (colour.alpha >= 1) {
          break;
        }
      }
    }
    return layers.reverse().reduce((under, layer) => over(layer, under), {
      red: 255,
      green: 255,
      blue: 255,
      alpha: 1,
    });
  };
  const luminance = ({ red, green, blue }) => {
    const [r, g, b] = [red, green, blue].map((channel) => {
      const value = channel / 255;
      return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const hex = ({ red, green, blue }) =>
    `#${[red, green, blue].map((channel) => Math.round(channel).toString(16).padStart(2, '0')).join('')}`;

  const scope = '.notebook-article__header, .notebook-article__sidebar, .notebook-article__content';
  return [...document.querySelectorAll(scope)]
    .flatMap((root) => [root, ...root.querySelectorAll('*')])
    .filter((element) => !element.closest('mjx-container, svg'))
    .filter((element) => [...element.childNodes].some((node) => node.nodeType === 3 && node.textContent.trim()))
    .filter((element) => element.getClientRects().length > 0)
    .map((element) => {
      const style = getComputedStyle(element);
      const background = backdrop(element);
      const ink = over(parse(style.color), background);
      const [lighter, darker] = [luminance(ink), luminance(background)].sort((a, b) => b - a);
      const size = parseFloat(style.fontSize);
      const large = size >= 24 || (size >= 18.66 && Number(style.fontWeight) >= 700);
      return {
        text: element.textContent.trim().replace(/\s+/g, ' ').slice(0, 40),
        ratio: Math.round(((lighter + 0.05) / (darker + 0.05)) * 100) / 100,
        needs: large ? 3 : 4.5,
        colours: `${hex(ink)} on ${hex(background)}`,
      };
    });
};

test.describe('Notebook colours', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  for (const theme of ['light', 'dark']) {
    test(`every text on the notebook page reads in ${theme} mode`, async ({ page }) => {
      await page.addInitScript((mode) => {
        window.localStorage.setItem('datalog-color-mode', mode);
      }, theme);
      await page.goto(new URL(notebook, baseUrl).href, { waitUntil: 'load' });
      await expect(page.locator('body')).toHaveAttribute('data-theme', theme);
      // MathJax replaces the inline equation's text as it typesets, so the
      // measuring waits until it has.
      await page.locator('mjx-container[role="math"]').first().waitFor({ state: 'attached' });
      await page
        .locator('.notebook-cell--input')
        .first()
        .evaluate((cell, markup) => {
          cell.insertAdjacentHTML('beforeend', markup);
        }, OUTPUTS);

      const texts = await page.evaluate(measure);
      // The header's label and values, the sidebar's counts and an output's
      // warning are all among what was measured.
      for (const expected of ['Interactive Notebook', 'Kernel: Python 3', 'code cells', 'Plotly figure']) {
        expect(
          texts.some((entry) => entry.text.includes(expected)),
          expected,
        ).toBe(true);
      }

      const failures = texts
        .filter((entry) => entry.ratio < entry.needs)
        .map((entry) => `"${entry.text}": ${entry.colours} = ${entry.ratio}:1 (needs ${entry.needs}:1)`);
      expect(failures, `low-contrast text in ${theme} mode`).toEqual([]);
    });
  }
});
