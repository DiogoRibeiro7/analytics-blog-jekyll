import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const visualEnabled = !!process.env.PLAYWRIGHT_ENABLE_VISUALS;

test.describe('Visualization loading', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('lazy loads charts and reveals accessible tables', async ({ page }) => {
    await page.addInitScript(() => {
      if (!window.Plotly) {
        window.Plotly = {
          newPlot: () => Promise.resolve(),
          downloadImage: () => Promise.resolve()
        };
      }
    });

    await page.addInitScript(() => {
      if (!window.__datalogWidgetManagerPromise) {
        window.__datalogWidgetManagerPromise = Promise.resolve({
          WidgetManager: class {
            set_state() {
              return Promise.resolve();
            }

            get_model() {
              return Promise.resolve({});
            }

            create_view() {
              return Promise.resolve({});
            }

            display_view(_model, _view, options) {
              const el = options && options.el;
              if (el && !el.querySelector('[data-test-widget-placeholder]')) {
                const placeholder = document.createElement('div');
                placeholder.setAttribute('data-test-widget-placeholder', 'true');
                placeholder.textContent = 'Widget ready';
                el.appendChild(placeholder);
              }
              return Promise.resolve();
            }
          }
        });
      }
    });

    await page.goto(`${baseUrl}/visualizations/`, { waitUntil: 'domcontentloaded' });

    const targetBlock = page.locator('[data-viz-type="plotly"]');
    const status = targetBlock.locator('[data-viz-status]');
    const toggle = targetBlock.locator('[data-viz-table-toggle]');
    const tableWrapper = targetBlock.locator('[data-viz-table-wrapper]');

    await page.waitForFunction(
      () => document?.body?.dataset?.featureVisualizationsState === 'ready',
      { timeout: 20000 }
    );

    await targetBlock.scrollIntoViewIfNeeded();

    try {
      await expect(status).toContainText(/Loading/i, { timeout: 5000 });
    } catch (error) {
      // Visualization may render immediately in some environments.
    }

    await expect(status).toContainText(/Interactive/i, { timeout: 20000 });
    await expect(toggle).toHaveCount(1, { timeout: 20000 });
    await expect(tableWrapper).toHaveCount(1, { timeout: 20000 });
    await expect(tableWrapper).toBeHidden();

    await expect(toggle).toBeVisible();
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');

    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-expanded', 'true');
    await expect(tableWrapper).toBeVisible();
    await expect(tableWrapper.locator('table')).toBeVisible();
    await expect(tableWrapper.locator('caption')).toHaveCount(1);
  });

  test('homepage visual baseline @visual', async ({ page }) => {
    test.skip(!visualEnabled, 'Visual regression checks are disabled.');

    await page.goto(`${baseUrl}/`, { waitUntil: 'networkidle' });
    await expect(page).toHaveScreenshot('homepage-desktop.png', {
      animations: 'disabled',
      fullPage: true
    });
  });
});
