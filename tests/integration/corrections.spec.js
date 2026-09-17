import { expect, test } from '@playwright/test';

/**
 * The correction-report form (#256) against a mocked backend: the browser
 * suite builds the site with tests/integration/site-config.yml, which points
 * the dynamic services at https://api.example.test, and each test answers
 * that address itself.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const post = '/2024/04/05/sql-optimization-guide/';
const api = 'https://api.example.test/v1/';

function serve(page, answers) {
  const calls = [];
  return page.route(`${api}**`, async (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname.replace('/v1', '');
    calls.push({ path, method: request.method(), body: request.postDataJSON?.() ?? null, headers: request.headers() });
    const answer = answers[path] || answers['*'];
    if (!answer) {
      return route.fulfill({ status: 404, contentType: 'application/json', body: '{}' });
    }
    if (answer.abort) {
      return route.abort('failed');
    }
    return route.fulfill({
      status: answer.status || 200,
      contentType: 'application/json',
      // A real backend exposes these too (docs/dynamic-services.md, CORS).
      headers: { 'Access-Control-Expose-Headers': 'X-Request-Id, Retry-After', ...(answer.headers || {}) },
      body: JSON.stringify(answer.body || {}),
    });
  }).then(() => calls);
}

const capabilities = { body: { api_version: '1', features: { corrections: true, contact: true } } };

async function openAndFill(page, message) {
  await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
  const details = page.locator('[data-correction-report]');
  await details.locator('summary').click();
  await page.selectOption('#correction-category', 'code');
  await page.selectOption('#correction-section', 'optimization-checklist');
  await page.fill('#correction-message', message);
  return details;
}

test.describe('Correction reports', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('a report reaches the service with the article attached and the form says thank you', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      '/corrections': { status: 202, body: { status: 'received' }, headers: { 'X-Request-Id': 'req_ok' } },
    });
    const details = await openAndFill(page, 'The clustering step names purchase_ts but the table clusters on customer_id.');
    await page.fill('#correction-email', 'reader@example.org');
    await details.locator('button[type=submit]').click();

    const form = page.locator('#correction-report-form');
    await expect(form).toHaveAttribute('data-state', 'success');
    await expect(form.locator('[data-form-status]')).toContainText('Thank you');
    await expect(page.locator('#correction-message')).toHaveValue('');

    const report = calls.find((call) => call.path === '/corrections');
    expect(report.method).toBe('POST');
    expect(report.headers['idempotency-key']).toMatch(/\S+/);
    expect(report.body).toMatchObject({
      category: 'code',
      section: 'optimization-checklist',
      contact_email: 'reader@example.org',
      article: { url: `https://diogoribeiro7.github.io${post}`, title: 'SQL Optimization Playbook for Warehouse Analysts' },
    });
    expect(calls.filter((call) => call.path === '/capabilities')).toHaveLength(1);
  });

  test('a short message is refused before anything is sent', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities });
    const details = await openAndFill(page, 'Wrong.');
    await details.locator('button[type=submit]').click();

    const form = page.locator('#correction-report-form');
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('#correction-message')).toHaveAttribute('aria-invalid', 'true');
    await expect(page.locator('[data-error-for="message"]')).toContainText('20 characters');
    await expect(page.locator('#correction-message')).toBeFocused();
    expect(calls.filter((call) => call.path === '/corrections')).toHaveLength(0);
  });

  test('the service’s validation, a rate limit and a failure each show their state', async ({ page }) => {
    await serve(page, {
      '/capabilities': capabilities,
      '/corrections': { status: 422, body: { error: { code: 'invalid', message: 'Check.', errors: { message: 'Name the section.' } } } },
    });
    const details = await openAndFill(page, 'Something in the checklist is wrong, in my reading.');
    await details.locator('button[type=submit]').click();
    const form = page.locator('#correction-report-form');
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('[data-error-for="message"]')).toHaveText('Name the section.');

    await page.unroute(`${api}**`);
    await serve(page, {
      '/capabilities': capabilities,
      '/corrections': { status: 429, body: {}, headers: { 'Retry-After': '30', 'X-Request-Id': 'req_slow' } },
    });
    await details.locator('button[type=submit]').click();
    await expect(form).toHaveAttribute('data-state', 'error');
    await expect(form.locator('[data-form-status]')).toContainText('Too many requests');
    await expect(form.locator('[data-form-status]')).toContainText('req_slow');
    await expect(form.locator('[data-form-status]')).toHaveAttribute('role', 'alert');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, '/corrections': { abort: true } });
    await details.locator('button[type=submit]').click();
    await expect(form).toHaveAttribute('data-state', 'error');
    await expect(form.locator('[data-form-status]')).toContainText('could not be reached');
    await expect(details.locator('button[type=submit]')).toBeEnabled();
  });

  test('a service without the feature, or of another version, disables the form', async ({ page }) => {
    await serve(page, { '/capabilities': { body: { api_version: '1', features: { corrections: false } } } });
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
    const details = page.locator('[data-correction-report]');
    await details.locator('summary').click();

    const form = page.locator('#correction-report-form');
    await expect(form).toHaveAttribute('data-state', 'disabled');
    await expect(form.locator('[data-form-status]')).toContainText('does not offer');
    await expect(details.locator('button[type=submit]')).toBeDisabled();

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': { body: { api_version: '2', features: { corrections: true } } } });
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-correction-report] summary').click();
    await expect(form).toHaveAttribute('data-state', 'disabled');
    await expect(form.locator('[data-form-status]')).toContainText('different API versions');
  });
});
