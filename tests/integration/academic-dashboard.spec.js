import { expect, test } from '@playwright/test';

/**
 * The academic dashboard at /academic/ (#355). Its script filters the
 * submissions by status and the calendar by event type, and sizes the bars
 * for citations by year, none of which had run on a page before.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Academic dashboard', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test.beforeEach(async ({ page }) => {
    await page.goto(new URL('/academic/', baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('body')).toHaveAttribute('data-feature-academic-state', 'ready');
  });

  test('the status filter shows the submissions with that status', async ({ page }) => {
    const cards = page.locator('.submission-card');
    const total = await cards.count();
    expect(total).toBeGreaterThan(1);

    const filter = page.locator('[data-submission-filter]');
    const status = await filter.locator('option').nth(1).getAttribute('value');
    await filter.selectOption(status);
    await expect(page.locator(`.submission-card[data-submission-status="${status}"]`).first()).toBeVisible();
    await expect(page.locator(`.submission-card:not([data-submission-status="${status}"])`).first()).toBeHidden();

    await filter.selectOption('');
    await expect(cards.last()).toBeVisible();
  });

  test('the event filter shows the events of that type', async ({ page }) => {
    const filter = page.locator('[data-calendar-filter]');
    const type = await filter.locator('option').nth(1).getAttribute('value');
    await filter.selectOption(type);

    const shown = await page.locator('[data-academic-calendar] > li').evaluateAll((items) =>
      items.filter((item) => item.checkVisibility()).map((item) => item.dataset.eventType)
    );
    expect(shown.length).toBeGreaterThan(0);
    expect(new Set(shown)).toEqual(new Set([type]));
  });

  test('each year of citations is a bar in proportion to the busiest', async ({ page }) => {
    const bars = await page.locator('[data-citation-timeline] li[data-year]').evaluateAll((items) =>
      items.map((item) => ({
        total: Number(item.querySelector('[data-year-total]').textContent.replace(/\D/g, '')),
        width: item.style.getPropertyValue('--timeline-value')
      }))
    );
    const largest = Math.max(...bars.map((bar) => bar.total));

    expect(bars.length).toBeGreaterThan(1);
    for (const bar of bars) {
      expect(bar.width).toBe(`${Math.round((bar.total / largest) * 100)}%`);
    }
  });
});
