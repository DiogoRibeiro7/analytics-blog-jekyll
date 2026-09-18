import { expect, test } from '@playwright/test';

/**
 * The contact and collaboration form (#261) against a mocked backend: the
 * browser suite builds the site with tests/integration/site-config.yml,
 * which points the dynamic services at https://api.example.test, and each
 * test answers that address itself.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
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

async function openAndFill(page, overrides = {}) {
  await page.goto(new URL('/contact/', baseUrl).href, { waitUntil: 'load' });
  const values = {
    '#contact-name': 'Jane Doe',
    '#contact-email': 'jane@example.org',
    '#contact-affiliation': 'Example University',
    '#contact-subject': 'Potential collaboration on longitudinal models',
    '#contact-message': 'We have adherence data over five years and would like to model it together.',
    ...overrides,
  };
  await page.selectOption('#contact-category', 'research-collaboration');
  for (const [selector, value] of Object.entries(values)) {
    await page.fill(selector, value);
  }
  return page.locator('#contact-form');
}

test.describe('Contact form', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('a message reaches the service with the page attached and the form says thank you', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      '/contact': { status: 202, body: { status: 'received' }, headers: { 'X-Request-Id': 'req_ok' } },
    });
    const form = await openAndFill(page);
    await expect(page.locator('#contact-message-hint')).toContainText('question, data or method');
    await form.locator('button[type=submit]').click();

    await expect(form).toHaveAttribute('data-state', 'success');
    await expect(form.locator('[data-form-status]')).toContainText('Thank you');
    await expect(page.locator('#contact-message')).toHaveValue('');

    const message = calls.find((call) => call.path === '/contact');
    expect(message.method).toBe('POST');
    expect(message.headers['idempotency-key']).toMatch(/\S+/);
    expect(message.body).toEqual({
      category: 'research-collaboration',
      name: 'Jane Doe',
      email: 'jane@example.org',
      affiliation: 'Example University',
      subject: 'Potential collaboration on longitudinal models',
      message: 'We have adherence data over five years and would like to model it together.',
      source_url: 'https://diogoribeiro7.github.io/contact/',
    });
    expect(calls.filter((call) => call.path === '/capabilities')).toHaveLength(1);
  });

  test('missing fields are refused before anything is sent', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities });
    const form = await openAndFill(page, { '#contact-name': '', '#contact-email': 'jane', '#contact-message': 'Hello.' });
    await form.locator('button[type=submit]').click();

    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('#contact-name')).toBeFocused();
    await expect(page.locator('#contact-form [data-error-for="name"]')).toBeVisible();
    await expect(page.locator('#contact-form [data-error-for="email"]')).toContainText('email');
    await expect(page.locator('#contact-form [data-error-for="message"]')).toContainText('20 characters');
    expect(calls.filter((call) => call.path === '/contact')).toHaveLength(0);
  });

  test('the service’s validation, a rate limit and a failure each show their state', async ({ page }) => {
    await serve(page, {
      '/capabilities': capabilities,
      '/contact': { status: 422, body: { error: { code: 'invalid', message: 'Check.', errors: { email: 'Use an institutional address.' } } } },
    });
    const form = await openAndFill(page);
    await form.locator('button[type=submit]').click();
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('#contact-form [data-error-for="email"]')).toHaveText('Use an institutional address.');
    await expect(page.locator('#contact-message')).not.toHaveValue('');

    await page.unroute(`${api}**`);
    await serve(page, {
      '/capabilities': capabilities,
      '/contact': { status: 429, body: {}, headers: { 'Retry-After': '30', 'X-Request-Id': 'req_slow' } },
    });
    await form.locator('button[type=submit]').click();
    await expect(form).toHaveAttribute('data-state', 'error');
    await expect(form.locator('[data-form-status]')).toContainText('Too many requests');
    await expect(form.locator('[data-form-status]')).toContainText('req_slow');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, '/contact': { status: 500, body: { error: { code: 'server' } } } });
    await form.locator('button[type=submit]').click();
    await expect(form).toHaveAttribute('data-state', 'error');
    await expect(form.locator('[data-form-status]')).toContainText('ran into a problem');
    await expect(form.locator('button[type=submit]')).toBeEnabled();
  });

  test('a service without the feature disables the form', async ({ page }) => {
    await serve(page, { '/capabilities': { body: { api_version: '1', features: { contact: false } } } });
    await page.goto(new URL('/contact/', baseUrl).href, { waitUntil: 'load' });
    await page.locator('#contact-name').focus();

    const form = page.locator('#contact-form');
    await expect(form).toHaveAttribute('data-state', 'disabled');
    await expect(form.locator('[data-form-status]')).toContainText('does not offer');
    await expect(form.locator('button[type=submit]')).toBeDisabled();
  });
});
