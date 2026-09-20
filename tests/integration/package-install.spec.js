import { expect, test } from '@playwright/test';

/**
 * The installation panel on a package page. Its tabs were three buttons with
 * no tab semantics and no keyboard beyond Tab, its copy button was a second
 * clipboard implementation with no fallback, and the panel's id collided with
 * the one kramdown gives an `## Installation` heading (#332).
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const page_url = '/packages/statflow/';

test.describe('Installation panel', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.goto(new URL(page_url, baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('[data-install-tabs]')).toHaveCount(1);
  });

  test('the page has no id twice over', async ({ page }) => {
    const duplicates = await page.evaluate(() => {
      const counts = {};
      document.querySelectorAll('[id]').forEach((node) => {
        counts[node.id] = (counts[node.id] || 0) + 1;
      });
      return Object.entries(counts).filter(([, count]) => count > 1).map(([id]) => id);
    });
    expect(duplicates).toEqual([]);
  });

  test('the tabs are a tablist the arrow keys move through', async ({ page }) => {
    const tabs = page.locator('[role="tablist"] [role="tab"]');
    await expect(tabs).toHaveCount(3);
    await expect(tabs.first()).toHaveAttribute('aria-selected', 'true');

    await tabs.first().focus();
    await page.keyboard.press('ArrowRight');

    await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true');
    await expect(tabs.nth(1)).toBeFocused();
    await expect(page.locator('[data-tab-content="conda"]')).toBeVisible();
    await expect(page.locator('[data-tab-content="pip"]')).toBeHidden();
  });

  test('a panel is named by the tab that shows it', async ({ page }) => {
    const panels = page.locator('[role="tabpanel"]');
    await expect(panels).toHaveCount(3);

    const named = await panels.evaluateAll((nodes) =>
      nodes.every((node) => {
        const tab = document.getElementById(node.getAttribute('aria-labelledby'));
        return tab !== null && tab.getAttribute('aria-controls') === node.id;
      })
    );
    expect(named).toBe(true);
  });

  test('the copy button copies the command it sits beside', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    const button = page.locator('[data-tab-content="pip"] .package-install__copy-btn');

    await button.click();

    await expect(button).toHaveAttribute('data-copied', 'true');
    const copied = await page.evaluate(() => navigator.clipboard.readText());
    expect(copied).toBe('pip install statflow');
  });

  test('every button says what it is', async ({ page }) => {
    const untyped = page.locator('.package-install button:not([type])');
    await expect(untyped).toHaveCount(0);
  });
});
