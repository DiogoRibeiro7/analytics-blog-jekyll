import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Analytics dashboard presentation', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  for (const width of [390, 1280]) {
    for (const mode of ['dark', 'light']) {
      test(`unavailable data stays readable at ${width}px in ${mode} mode`, async ({ page }) => {
        await page.setViewportSize({ width, height: 860 });
        await page.goto(`${baseUrl}/admin/analytics/`);
        if (await page.locator('body').getAttribute('data-theme') !== mode) {
          await page.locator('[data-toggle-dark-mode]').click();
        }

        await expect(page.locator('body')).toHaveAttribute('data-theme', mode);
        await expect(page.locator('.analytics-dashboard')).toHaveAttribute('data-status', 'missing_configuration');
        await expect(page.locator('.analytics-state')).toHaveText('Setup needed');
        await expect(page.locator('.analytics-alert')).toBeVisible();
        await expect(page.locator('#analytics-visitors-chart')).toBeHidden();
        await expect(page.locator('.analytics-chart-status').first()).toHaveText('No chart data available.');
        await page.locator('.analytics-card--wide .analytics-table-scroll').last().focus();
        await expect(page.locator('.analytics-card--wide .analytics-table-scroll').last()).toBeFocused();
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
      });
    }
  }

  test('populated chart data remains available in a table after a theme change', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 860 });
    await page.goto(`${baseUrl}/admin/analytics/`);

    await page.evaluate(async () => {
      window.__DATALOG_ANALYTICS__ = {
        status: 'ok',
        visitor_trends: { rows: [{ dimensionValues: [{ value: '20260927' }],
          metricValues: [{ value: '12' }, { value: '4' }, { value: '9' }, { value: '17' }] }] },
        top_posts: { rows: [{ dimensionValues: [{ value: '/a/very/long/research/article/path' }],
          metricValues: [{ value: '17' }, { value: '13' }] }] },
        monthly_reports: [{ month: '2026-09', total_users: 12, new_users: 4, sessions: 9, page_views: 17 }]
      };
      const source = document.querySelector('script[type="module"][src*="analytics-dashboard"]').src;
      const { render } = await import(source);
      render();
    });

    const data = page.locator('.analytics-card:has(#analytics-visitors-chart) .analytics-chart-data');
    await expect(data).toBeVisible();
    await data.locator('summary').click();
    await expect(data.locator('tbody th')).toHaveText('2026-09-27');
    await expect(data.locator('tbody td')).toHaveText(['12', '4', '9', '17']);
    const firstColour = await page.locator('.analytics-dashboard').evaluate((element) =>
      getComputedStyle(element).getPropertyValue('--analytics-series-1').trim());
    await page.locator('[data-toggle-dark-mode]').click();
    const secondColour = await page.locator('.analytics-dashboard').evaluate((element) =>
      getComputedStyle(element).getPropertyValue('--analytics-series-1').trim());
    expect(secondColour).not.toBe(firstColour);
    await expect(data.locator('tbody td')).toHaveText(['12', '4', '9', '17']);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  });
});
