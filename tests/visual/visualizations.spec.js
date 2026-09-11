import { expect, test } from '@playwright/test';
import { captureSnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadGallery(page) {
  await page.goto(`${normalizedBaseUrl}/visualizations/`, { waitUntil: 'networkidle' });
  await page.waitForLoadState('networkidle');
  await stabilizePage(page);
}

test.describe('Visualization gallery scenarios', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  const visualizationTypes = [
    { type: 'plotly', name: 'visualizations-plotly' },
    { type: 'd3', name: 'visualizations-d3' },
    { type: 'observable', name: 'visualizations-observable' },
    { type: 'bokeh', name: 'visualizations-bokeh' },
    { type: 'shiny', name: 'visualizations-shiny' },
    { type: 'ipywidgets', name: 'visualizations-ipywidgets' }
  ];

  for (const viewport of viewports) {
    test.describe(`${viewport.name} viewport`, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      test.beforeEach(async ({ page }) => {
        await loadGallery(page);
      });

      for (const viz of visualizationTypes) {
        test(`@visual ${viz.type} block (${viewport.name})`, async ({ page }) => {
          const block = page.locator(`[data-viz-type="${viz.type}"]`).first();
          await block.scrollIntoViewIfNeeded();
          await expect(block).toBeVisible();

          const toggle = block.locator('.viz-table-toggle');
          await expect(toggle).toBeVisible();

          const toggleTarget = await toggle.getAttribute('aria-controls');
          expect(toggleTarget).toBeTruthy();

          const table = block.locator('table.viz-table');
          const tableCount = await table.count();
          expect(tableCount).toBeGreaterThanOrEqual(1);
          const captionText = (await table.locator('caption').textContent())?.trim() ?? '';
          expect(captionText.length).toBeGreaterThan(0);

          const headerCellCount = await table.locator('thead th').count();
          expect(headerCellCount).toBeGreaterThan(0);

          const describedBy = await block.getAttribute('aria-describedby');
          if (describedBy && toggleTarget) {
            expect(describedBy.split(/\s+/)).toContain(toggleTarget);
          }

          await captureSnapshot(page, `${viz.type} visualization (${viewport.name})`, {
            scope: `[data-viz-type="${viz.type}"]`
          });
        });
      }
    });
  }
});
