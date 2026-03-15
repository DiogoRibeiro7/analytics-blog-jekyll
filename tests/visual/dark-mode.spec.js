import { expect, test } from '@playwright/test';
import { capturePercySnapshot, stabilizePage, viewports } from './helpers.js';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const normalizedBaseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : '';

async function loadDarkPage(page, path) {
  await page.addInitScript(() => {
    try {
      window.localStorage.setItem('datalog-color-mode', 'dark');
    } catch (error) {
      // Ignore storage failures in sandboxed contexts
    }
  });
  await page.goto(`${normalizedBaseUrl}${path}`, { waitUntil: 'networkidle' });
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.waitForLoadState('networkidle');
  await page.evaluate(() => {
    document.body.classList.add('dark-mode');
  });
  await stabilizePage(page);
}

test.describe('Dark mode visual coverage', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run visual regression scenarios.');

  const pages = [
    { name: 'homepage', path: '/' },
    { name: 'post', path: '/2024/04/08/mathematical-proof-numbered-equations/' },
    { name: 'search', path: '/search/' },
    { name: 'visualizations', path: '/visualizations/' }
  ];

  for (const viewport of viewports) {
    test.describe(`${viewport.name} viewport`, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      for (const entry of pages) {
        test(`@visual ${entry.name} dark mode (${viewport.name})`, async ({ page }) => {
          await loadDarkPage(page, entry.path);

          const isDark = await page.evaluate(() => document.body.classList.contains('dark-mode'));
          expect(isDark).toBeTruthy();

          const colorTokens = await page.evaluate(() => {
            const bodyStyles = window.getComputedStyle(document.body);
            const header = document.querySelector('.site-header');
            const headerStyles = header ? window.getComputedStyle(header) : null;
            return {
              bodyBackground: bodyStyles.backgroundColor,
              bodyColor: bodyStyles.color,
              headerBackground: headerStyles?.backgroundColor ?? ''
            };
          });

          expect(colorTokens.bodyBackground).not.toBe('rgb(255, 255, 255)');
          expect(colorTokens.bodyBackground).not.toBe('rgba(0, 0, 0, 0)');
          expect(colorTokens.bodyColor).not.toBe('rgb(0, 0, 0)');

          await capturePercySnapshot(page, `${entry.name} dark mode (${viewport.name})`, {
            fullPage: true
          });
        });
      }
    });
  }
});
