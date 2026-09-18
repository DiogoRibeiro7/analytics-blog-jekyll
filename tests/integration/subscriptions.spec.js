import { expect, test } from '@playwright/test';

/**
 * Newsletter subscriptions (#254) against a mocked backend: the browser
 * suite builds the site with tests/integration/site-config.yml, which turns
 * the feature on with the form in the footer and at the end of posts, and
 * each test answers https://api.example.test itself.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const api = 'https://api.example.test/v1/';

function serve(page, answers) {
  const calls = [];
  return page.route(`${api}**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname.replace('/v1', '');
    calls.push({ path, method: request.method(), body: request.postDataJSON?.() ?? null, headers: request.headers() });
    const answer = answers[`${request.method()} ${path}`] || answers[path];
    if (!answer) {
      return route.fulfill({ status: 404, contentType: 'application/json', body: '{}' });
    }
    if (answer.abort) {
      return route.abort('failed');
    }
    return route.fulfill({
      status: answer.status || 200,
      contentType: 'application/json',
      headers: { 'Access-Control-Expose-Headers': 'X-Request-Id, Retry-After', ...(answer.headers || {}) },
      body: answer.status === 204 ? '' : JSON.stringify(answer.body || {}),
    });
  }).then(() => calls);
}

const capabilities = { body: { api_version: '1', features: { subscriptions: true } } };

test.describe('Newsletter subscriptions', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the footer form subscribes and says to check the inbox; a post carries its own form', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities, 'POST /subscriptions': { status: 202, body: { status: 'pending' } } });
    await page.goto(new URL('/', baseUrl).href, { waitUntil: 'load' });
    const form = page.locator('#subscribe-form-footer');
    await page.fill('#subscribe-email-footer', 'reader@example.org');
    await page.uncheck('#subscribe-topic-footer-datasets');
    await form.locator('button[type=submit]').click();

    await expect(form).toHaveAttribute('data-state', 'success');
    await expect(form).toHaveAttribute('data-result', 'pending');
    await expect(form.locator('[data-form-status]')).toContainText('Check your inbox');
    const sent = calls.find((call) => call.method === 'POST');
    expect(sent.headers['idempotency-key']).toMatch(/\S+/);
    expect(sent.body).toEqual({
      email: 'reader@example.org',
      topics: ['new-articles', 'research-notes'],
      source_url: 'https://diogoribeiro7.github.io/',
      locale: 'en',
    });

    await page.goto(new URL('/2024/04/05/sql-optimization-guide/', baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('#subscribe-form-post')).toHaveCount(1);
    await expect(page.locator('#subscribe-form-footer')).toHaveCount(1);
  });

  test('confirmed at once, a duplicate, a bad address, a 422, a rate limit and a failure each show their state', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, 'POST /subscriptions': { status: 201, body: { status: 'confirmed' } } });
    await page.goto(new URL('/', baseUrl).href, { waitUntil: 'load' });
    const form = page.locator('#subscribe-form-footer');
    const status = form.locator('[data-form-status]');
    const submit = form.locator('button[type=submit]');

    await page.fill('#subscribe-email-footer', 'not-an-email');
    await submit.click();
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('#subscribe-email-footer')).toHaveAttribute('aria-invalid', 'true');
    await expect(page.locator('#subscribe-email-footer')).toBeFocused();

    await page.fill('#subscribe-email-footer', 'reader@example.org');
    await submit.click();
    await expect(form).toHaveAttribute('data-result', 'confirmed');
    await expect(status).toContainText('You are subscribed');

    const next = async (answer) => {
      await page.unroute(`${api}**`);
      await serve(page, { '/capabilities': capabilities, 'POST /subscriptions': answer });
      await page.fill('#subscribe-email-footer', 'reader@example.org');
      await submit.click();
    };

    await next({ status: 409, body: { error: { code: 'already_subscribed' } } });
    await expect(form).toHaveAttribute('data-result', 'duplicate');
    await expect(status).toContainText('already subscribed');

    await next({ status: 422, body: { error: { code: 'invalid', errors: { email: 'This domain cannot receive mail.' } } } });
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(form.locator('[data-error-for="email"]')).toHaveText('This domain cannot receive mail.');

    await next({ status: 429, body: {}, headers: { 'Retry-After': '60', 'X-Request-Id': 'req_slow' } });
    await expect(form).toHaveAttribute('data-state', 'error');
    await expect(status).toContainText('Too many requests');
    await expect(status).toContainText('req_slow');

    await next({ abort: true });
    await expect(status).toContainText('could not be reached');
    await expect(page.locator('#subscribe-email-footer')).toHaveValue('reader@example.org');
    await expect(submit).toBeEnabled();
  });

  test('the link in an email confirms, and the token leaves the address bar', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities, 'POST /subscriptions/confirm': { body: { status: 'confirmed' } } });
    await page.goto(new URL('/subscriptions/?confirm=tok_confirm_12345', baseUrl).href, { waitUntil: 'load' });
    const root = page.locator('[data-subscription-manage]');

    await expect(root).toHaveAttribute('data-state', 'confirmed');
    await expect(root.locator('[data-manage-status]')).toContainText('confirmed');
    expect(calls.find((call) => call.method === 'POST').body).toEqual({ token: 'tok_confirm_12345' });
    expect(new URL(page.url()).search).toBe('');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities });
    await page.goto(new URL('/subscriptions/?confirm=tok_expired_12345', baseUrl).href, { waitUntil: 'load' });
    await expect(root).toHaveAttribute('data-state', 'error');
    await expect(root.locator('[data-manage-status]')).toContainText('not valid any more');
  });

  test('unsubscribing takes a press of the button, and the topics can be changed', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      'DELETE /subscriptions/tok_unsub_123456': { status: 204 },
      'GET /subscriptions/tok_manage_12345': { body: { status: 'confirmed', topics: ['new-articles', 'datasets'] } },
      'PATCH /subscriptions/tok_manage_12345': { body: { topics: ['datasets'] } },
    });
    await page.goto(new URL('/subscriptions/?unsubscribe=tok_unsub_123456', baseUrl).href, { waitUntil: 'load' });
    const root = page.locator('[data-subscription-manage]');
    await expect(root.locator('[data-manage-unsubscribe-panel]')).toBeVisible();
    expect(calls.filter((call) => call.method === 'DELETE')).toHaveLength(0);
    await root.locator('[data-manage-unsubscribe-panel] [data-manage-unsubscribe]').click();
    await expect(root).toHaveAttribute('data-state', 'unsubscribed');
    await expect(root.locator('[data-manage-status]')).toContainText('unsubscribed');
    expect(calls.filter((call) => call.method === 'DELETE')).toHaveLength(1);

    await page.goto(new URL('/subscriptions/?manage=tok_manage_12345', baseUrl).href, { waitUntil: 'load' });
    const preferences = page.locator('[data-manage-preferences]');
    await expect(preferences).toBeVisible();
    await expect(page.locator('#manage-topic-new-articles')).toBeChecked();
    await expect(page.locator('#manage-topic-research-notes')).not.toBeChecked();
    await page.uncheck('#manage-topic-new-articles');
    await preferences.locator('button[type=submit]').click();
    await expect(page.locator('[data-subscription-manage]')).toHaveAttribute('data-state', 'saved');
    expect(calls.find((call) => call.method === 'PATCH').body).toEqual({ topics: ['datasets'] });
  });
});
