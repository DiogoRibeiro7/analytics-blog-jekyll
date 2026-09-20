import { expect, test } from '@playwright/test';

/**
 * Article reactions (#255) against a mocked backend: the browser suite
 * builds the site with tests/integration/site-config.yml, which points the
 * dynamic services at https://api.example.test, and each test answers that
 * address itself.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const post = '/2024/04/05/sql-optimization-guide/';
const api = 'https://api.example.test/v1/';

function serve(page, answers) {
  const calls = [];
  return page.route(`${api}**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname.replace('/v1', '');
    calls.push({ path, method: request.method(), query: Object.fromEntries(url.searchParams), body: request.postDataJSON?.() ?? null, headers: request.headers() });
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
      body: JSON.stringify(answer.body || {}),
    });
  }).then(() => calls);
}

const capabilities = { body: { api_version: '1', features: { corrections: true, contact: true, comments: true, reactions: true } } };

async function open(page) {
  await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
  const strip = page.locator('[data-reactions]');
  await strip.scrollIntoViewIfNeeded();
  return strip;
}

const count = (page, reaction) => page.locator(`[data-reaction="${reaction}"] [data-reaction-count]`);

test.describe('Reactions', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the counts the service has are shown, and a reaction is sent, marked and remembered', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      'GET /reactions': { body: { counts: { useful: 42, 'needs-clarification': 3 } } },
      'POST /reactions': { status: 201, body: { counts: { useful: 43, 'needs-clarification': 3 }, reaction: 'useful' } },
    });
    const strip = await open(page);
    await expect(strip).toHaveAttribute('data-state', 'loaded');
    await expect(count(page, 'useful')).toHaveText('42');
    await expect(count(page, 'clear')).toBeHidden();
    expect(calls.find((call) => call.path === '/reactions').query.path).toBe(post);

    await page.click('[data-reaction="useful"]');
    await expect(strip).toHaveAttribute('data-state', 'selected');
    await expect(page.locator('[data-reaction="useful"]')).toHaveAttribute('aria-pressed', 'true');
    await expect(count(page, 'useful')).toHaveText('43');
    await expect(strip.locator('[data-reactions-status]')).toContainText('counted');
    const sent = calls.find((call) => call.method === 'POST');
    expect(sent.body).toEqual({ path: post, reaction: 'useful' });
    expect(sent.headers['idempotency-key']).toMatch(/\S+/);

    await page.reload({ waitUntil: 'load' });
    await expect(page.locator('[data-reaction="useful"]')).toHaveAttribute('aria-pressed', 'true');
    expect(await page.evaluate((key) => window.localStorage.getItem(key), `datalog-reaction:${post}`)).toBe('useful');
  });

  test('an unreadable service hides the counts but still takes a reaction; a rate limit and a conflict show their state', async ({ page }) => {
    await serve(page, {
      '/capabilities': capabilities,
      'GET /reactions': { status: 500, body: { error: { code: 'server' } } },
      'POST /reactions': { status: 429, body: {}, headers: { 'Retry-After': '30', 'X-Request-Id': 'req_slow' } },
    });
    const strip = await open(page);
    await expect(strip).toHaveAttribute('data-state', 'unavailable');
    await expect(count(page, 'useful')).toBeHidden();
    await expect(page.locator('[data-reaction="useful"]')).toBeEnabled();

    await page.click('[data-reaction="clear"]');
    const status = strip.locator('[data-reactions-status]');
    await expect(status).toContainText('Too many requests');
    await expect(status).toContainText('req_slow');
    await expect(status).toHaveAttribute('role', 'alert');
    await expect(page.locator('[data-reaction="clear"]')).toHaveAttribute('aria-pressed', 'false');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, 'POST /reactions': { status: 409, body: { error: { code: 'already_reacted' } } } });
    await page.click('[data-reaction="clear"]');
    await expect(page.locator('[data-reaction="clear"]')).toHaveAttribute('aria-pressed', 'false');
    await expect(status).toContainText('already');
  });

  test('a malformed answer shows no count, and a service without the feature disables the strip', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, 'GET /reactions': { body: { counts: 'lots' } } });
    const strip = await open(page);
    await expect(strip).toHaveAttribute('data-state', 'loaded');
    await expect(count(page, 'useful')).toBeHidden();

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': { body: { api_version: '1', features: { reactions: false } } } });
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-reactions]').scrollIntoViewIfNeeded();
    await expect(page.locator('[data-reactions]')).toHaveAttribute('data-state', 'disabled');
    await expect(page.locator('[data-reactions-status]')).toContainText('does not offer');
    await expect(page.locator('[data-reaction="useful"]')).toBeDisabled();
  });
});
