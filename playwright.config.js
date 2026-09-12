import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL;

if (!baseURL) {
  throw new Error(
    [
      'Playwright configuration error: PLAYWRIGHT_BASE_URL is not set.',
      'Set PLAYWRIGHT_BASE_URL to the URL of a served _site directory before running Playwright tests.',
      'For a fully automated workflow, run one of the npm helpers (e.g. "npm run test:integration") which build the site, start a server, and provide the base URL for you.'
    ].join('\n')
  );
}

export default defineConfig({
  testDir: 'tests',
  testMatch: ['**/*.spec.js'],
  timeout: 60000,
  expect: {
    timeout: 10000
  },
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    }
  ],
  workers: process.env.CI ? 2 : undefined,
  grep: process.env.PLAYWRIGHT_GREP ? new RegExp(process.env.PLAYWRIGHT_GREP) : undefined
});
