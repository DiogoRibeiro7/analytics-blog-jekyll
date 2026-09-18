import { expect, test } from '@playwright/test';

/**
 * The moderation inbox (#257) against a mocked moderation API: the browser
 * suite builds the site with tests/integration/site-config.yml, which turns
 * the inbox on, and each test answers https://api.example.test itself, as a
 * service that knows the moderator's session would, or would not.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const api = 'https://api.example.test/v1/';

const comment = {
  id: 'c_81', type: 'comment', status: 'pending', created_at: '2026-09-18T09:12:00Z',
  path: '/2024/04/05/sql-optimization-guide/', title: 'SQL Optimization Playbook',
  author: { name: 'Alice', email: 'alice@example.org' },
  body: 'Does the clustering step hold for skewed keys? <img src=x onerror=alert(1)>',
  history: [],
};
const report = {
  id: 'r_17', type: 'correction', status: 'new', created_at: '2026-09-17T16:40:00Z',
  path: '/2024/04/05/sql-optimization-guide/', category: 'code', section: 'optimization-checklist',
  quote: 'Cluster the fact table on purchase_ts', message: 'The table clusters on customer_id.',
  author: { email: 'reader@example.org' }, history: [],
};
const RESULT = { approve: 'approved', spam: 'spam', accept: 'accepted', resolve: 'resolved', reject: 'rejected' };

function serve(page, answers) {
  const calls = [];
  const origin = new URL(baseUrl).origin;
  return page.route(`${api}**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname.replace('/v1', '');
    calls.push({ path, method: request.method(), search: url.search, body: request.postDataJSON?.() ?? null, headers: request.headers() });
    let answer = answers[`${request.method()} ${path}`] || answers[path];
    if (typeof answer === 'function') {
      answer = answer(request.postDataJSON?.() ?? null);
    }
    if (!answer) {
      answer = { status: 404, body: {} };
    }
    return route.fulfill({
      status: answer.status || 200,
      contentType: 'application/json',
      // What a cookie-authenticated API sends: the exact origin and credentials allowed.
      headers: {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Expose-Headers': 'X-Request-Id, Retry-After',
        ...(answer.headers || {}),
      },
      body: JSON.stringify(answer.body || {}),
    });
  }).then(() => calls);
}

const capabilities = { body: { api_version: '1', features: { moderation: true } } };
const act = (item) => (payload) => ({ body: { item: { ...item, status: RESULT[payload.action], history: [{ action: payload.action, at: '2026-09-18T10:00:00Z', moderator: 'diogo', note: payload.note || '' }] } } });

test.describe('Moderation inbox', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the page is kept out of the index and linked from nowhere', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, 'GET /moderation/items': { body: { items: [] } } });
    await page.goto(new URL('/admin/moderation/', baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('meta[name="robots"]')).toHaveAttribute('content', 'noindex,nofollow');

    await page.goto(new URL('/', baseUrl).href, { waitUntil: 'load' });
    expect(await page.locator('a[href*="/admin/moderation/"]').count()).toBe(0);
  });

  test('the queue is listed as text, and approving a comment takes it out', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      'GET /moderation/items': { body: { items: [comment, report] } },
      'POST /moderation/items/c_81/actions': act(comment),
    });
    await page.goto(new URL('/admin/moderation/', baseUrl).href, { waitUntil: 'load' });
    const inbox = page.locator('[data-moderation-inbox]');

    await expect(inbox).toHaveAttribute('data-state', 'loaded');
    await expect(inbox.locator('[data-moderation-list] > li')).toHaveCount(2);
    const first = inbox.locator('[data-item-id="c_81"]');
    await expect(first.locator('.moderation-item__body')).toContainText('<img src=x onerror=alert(1)>');
    expect(await inbox.locator('[data-moderation-list] img').count()).toBe(0);
    await expect(first.locator('.moderation-item__author')).toHaveText('Alice · alice@example.org');

    await first.locator('input[name=note]').fill('Fine.');
    await first.locator('[data-moderation-action="approve"]').click();
    await expect(inbox.locator('[data-moderation-list] > li')).toHaveCount(1);
    await expect(inbox.locator('[data-moderation-status]')).toContainText('Done: Approve');
    const sent = calls.find((call) => call.method === 'POST');
    expect(sent.body).toEqual({ action: 'approve', note: 'Fine.' });
    expect(sent.headers['idempotency-key']).toMatch(/\S+/);
  });

  test('a report is accepted, then resolved with a link; spam and the filters reach the service', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      'GET /moderation/items': { body: { items: [comment, report] } },
      'POST /moderation/items/r_17/actions': act(report),
      'POST /moderation/items/c_81/actions': act(comment),
    });
    await page.goto(new URL('/admin/moderation/', baseUrl).href, { waitUntil: 'load' });
    const item = page.locator('[data-item-id="r_17"]');

    await item.locator('[data-moderation-action="accept"]').click();
    await expect(item).toHaveAttribute('data-item-status', 'accepted');
    await expect(item.locator('.moderation-item__history')).toContainText('diogo');
    await item.locator('[data-moderation-action="resolve"]').click();
    await expect(item.locator('[data-item-message]')).toContainText('address of the issue');
    await item.locator('input[name=link]').fill('https://github.com/example/site/pull/42');
    await item.locator('[data-moderation-action="resolve"]').click();
    await expect(page.locator('[data-item-id="r_17"]')).toHaveCount(0);
    expect(calls.filter((call) => call.method === 'POST').map((call) => call.body)).toEqual([
      { action: 'accept' },
      { action: 'resolve', link: 'https://github.com/example/site/pull/42' },
    ]);

    await page.locator('[data-item-id="c_81"] [data-moderation-action="spam"]').click();
    await expect(page.locator('[data-moderation-inbox]')).toHaveAttribute('data-state', 'empty');

    await page.selectOption('#moderation-status', 'spam');
    await page.fill('#moderation-search', 'casino');
    await page.click('#moderation-filters button[type=submit]');
    await expect.poll(() => calls.filter((call) => call.method === 'GET' && call.path === '/moderation/items').at(-1).search).toBe('?status=spam&q=casino');
  });

  test('a failed action leaves the item as it was, with the reason next to it', async ({ page }) => {
    await serve(page, {
      '/capabilities': capabilities,
      'GET /moderation/items': { body: { items: [comment] } },
      'POST /moderation/items/c_81/actions': { status: 500, body: { error: { code: 'server' } }, headers: { 'X-Request-Id': 'req_5' } },
    });
    await page.goto(new URL('/admin/moderation/', baseUrl).href, { waitUntil: 'load' });
    const item = page.locator('[data-item-id="c_81"]');
    await item.locator('[data-moderation-action="approve"]').click();

    await expect(item.locator('[data-item-message]')).toContainText('ran into a problem');
    await expect(item.locator('[data-item-message]')).toContainText('req_5');
    await expect(item.locator('[data-item-message]')).toHaveAttribute('role', 'alert');
    await expect(item).toHaveAttribute('data-item-status', 'pending');
    await expect(item.locator('[data-moderation-action="approve"]')).toBeEnabled();
  });

  test('signed out shows the way to sign in; not a moderator says so; neither shows an item', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, 'GET /moderation/items': { status: 401, body: { error: { code: 'unauthorized' } } } });
    await page.goto(new URL('/admin/moderation/', baseUrl).href, { waitUntil: 'load' });
    const inbox = page.locator('[data-moderation-inbox]');
    await expect(inbox).toHaveAttribute('data-state', 'unauthorized');
    await expect(inbox.locator('[data-moderation-status]')).toContainText('not signed in');
    await expect(inbox.locator('[data-moderation-sign-in] a')).toHaveAttribute('href', 'https://api.example.test/auth/login');
    await expect(inbox.locator('[data-moderation-list] > li')).toHaveCount(0);

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, 'GET /moderation/items': { status: 403, body: { error: { code: 'forbidden' } } } });
    await page.reload({ waitUntil: 'load' });
    await expect(inbox).toHaveAttribute('data-state', 'forbidden');
    await expect(inbox.locator('[data-moderation-status]')).toContainText('may not moderate');
    await expect(inbox.locator('[data-moderation-sign-in]')).toBeHidden();
  });
});
