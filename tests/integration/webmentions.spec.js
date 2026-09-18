import { expect, test } from '@playwright/test';

/**
 * "Mentioned elsewhere" (#258) against a mocked backend: the browser suite
 * builds the site with tests/integration/site-config.yml, which points the
 * dynamic services at https://api.example.test and names a Webmention
 * receiver, and each test answers the services address itself.
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
    calls.push({ path, method: request.method(), query: Object.fromEntries(url.searchParams) });
    const answer = answers[path];
    if (!answer) {
      return route.fulfill({ status: 404, contentType: 'application/json', body: '{}' });
    }
    return route.fulfill({
      status: answer.status || 200,
      contentType: 'application/json',
      headers: { 'Access-Control-Expose-Headers': 'X-Request-Id, Retry-After', ...(answer.headers || {}) },
      body: JSON.stringify(answer.body || {}),
    });
  }).then(() => calls);
}

const capabilities = { body: { api_version: '1', features: { corrections: true, contact: true, comments: true, reactions: true, webmentions: true } } };

const mentions = [
  { id: 'm1', source: 'https://example.org/bootstrap-uncertainty', target: `https://diogoribeiro7.github.io${post}`, type: 'reply', author: { name: 'Jane Doe', url: 'https://example.org' }, title: 'Bootstrap uncertainty in small samples', excerpt: 'Building on the clustering notes here, <b>with</b> a twist.', published_at: '2026-09-16T14:00:00Z', verified: true },
  { id: 'm2', source: 'https://notes.example.net/replication', type: 'mention', author: { name: 'Research Notes' }, title: 'A replication of the simulation study', published_at: '2026-09-17T09:00:00Z', verified: true },
  { id: 'm3', source: 'https://spam.example/x', type: 'mention', title: 'Unverified', verified: false },
  { id: 'm4', source: 'https://fan.example/like', type: 'like', verified: true },
];

async function open(page) {
  await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
  const section = page.locator('[data-webmentions]');
  await section.scrollIntoViewIfNeeded();
  return section;
}

test.describe('Webmentions', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the receiver is advertised in the head with the standard link', async ({ page }) => {
    await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });

    await expect(page.locator('head link[rel="webmention"]')).toHaveAttribute('href', 'https://mentions.example.test/webmention');
    await expect(page.locator('head link[rel="webmention"]')).toHaveCount(1);
  });

  test('verified mentions of the listed kinds are shown newest first, as text', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities, '/webmentions': { body: { mentions } } });
    const section = await open(page);

    await expect(section).toHaveAttribute('data-state', 'loaded');
    const items = section.locator('[data-webmentions-list] > li');
    await expect(items).toHaveCount(2);
    await expect(items.nth(0)).toHaveAttribute('data-mention-id', 'm2');
    await expect(items.nth(1)).toHaveAttribute('data-mention-id', 'm1');
    await expect(items.nth(1).locator('.webmention__title')).toHaveAttribute('href', 'https://example.org/bootstrap-uncertainty');
    await expect(items.nth(1).locator('.webmention__title')).toHaveAttribute('rel', 'nofollow noopener ugc');
    await expect(items.nth(1).locator('.webmention__excerpt')).toContainText('<b>with</b>');
    expect(await section.locator('[data-webmentions-list]').locator('b, script').count()).toBe(0);
    await expect(items.nth(1).locator('.webmention__type')).toHaveText('Reply');
    expect(calls.find((call) => call.path === '/webmentions').query.target).toBe(`https://diogoribeiro7.github.io${post}`);
  });

  test('an empty answer says so, a failure offers a retry, and a service without the feature hides the section', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, '/webmentions': { body: { mentions: [] } } });
    const section = await open(page);
    await expect(section).toHaveAttribute('data-state', 'empty');
    await expect(section.locator('[data-webmentions-status]')).toContainText('No mentions');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, '/webmentions': { status: 500, body: { error: { code: 'server' } } } });
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-webmentions]').scrollIntoViewIfNeeded();
    await expect(page.locator('[data-webmentions]')).toHaveAttribute('data-state', 'error');
    await expect(page.locator('[data-webmentions-status]')).toHaveAttribute('role', 'alert');
    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, '/webmentions': { body: { mentions } } });
    await page.click('[data-webmentions-retry]');
    await expect(page.locator('[data-webmentions]')).toHaveAttribute('data-state', 'loaded');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': { body: { api_version: '1', features: { webmentions: false } } } });
    await page.reload({ waitUntil: 'load' });
    // The browser restores the scroll position, so the section may already have
    // read the service and hidden itself; scrolling to a hidden element would wait.
    await page.locator('[data-webmentions]').scrollIntoViewIfNeeded({ timeout: 2000 }).catch(() => {});
    await expect(page.locator('[data-webmentions]')).toHaveAttribute('data-state', 'disabled');
    await expect(page.locator('[data-webmentions]')).toBeHidden();
  });
});
