import { expect, test } from '@playwright/test';

/**
 * The comments thread of the `api` provider (#253) against a mocked backend:
 * the browser suite builds the site with tests/integration/site-config.yml,
 * which gives every post without a comments key the api provider at
 * https://api.example.test, and each test answers that address itself.
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

const capabilities = { body: { api_version: '1', features: { corrections: true, contact: true, comments: true } } };

const comments = [
  { id: 'c1', parent_id: null, author: { name: 'Alice', url: 'https://alice.example' }, body: 'Clear charts.\n\nOne question: <script>alert(1)</script> is not run, is it?', created_at: '2026-09-16T15:30:00Z' },
  { id: 'c2', parent_id: 'c1', author: { name: 'Bob' }, body: 'It is not.', created_at: '2026-09-16T16:00:00Z' },
  { id: 'c3', parent_id: null, author: { name: 'Cléo' }, body: 'Thanks for the export notes.', created_at: '2026-09-16T17:00:00Z' },
];

async function open(page) {
  await page.goto(new URL(post, baseUrl).href, { waitUntil: 'load' });
  const thread = page.locator('[data-comments-thread]');
  await thread.scrollIntoViewIfNeeded();
  return thread;
}

test.describe('Comments (api provider)', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the thread loads for the page, nests the reply and renders bodies as text', async ({ page }) => {
    const calls = await serve(page, { '/capabilities': capabilities, 'GET /comments': { body: { comments } } });
    const thread = await open(page);

    await expect(thread).toHaveAttribute('data-state', 'loaded');
    const list = thread.locator('[data-comments-list]');
    await expect(list.locator('> li')).toHaveCount(2);
    await expect(list.locator('#comment-c1 > .comments-thread__replies > #comment-c2')).toHaveCount(1);
    await expect(list.locator('#comment-c1 > .comment__card .comment__body')).toContainText('<script>alert(1)</script>');
    expect(await list.locator('script').count()).toBe(0);
    await expect(list.locator('#comment-c1 > .comment__card .comment__author')).toHaveAttribute('href', 'https://alice.example');
    await expect(list.locator('#comment-c3 .comment__author')).toHaveText('Cléo');

    const read = calls.find((call) => call.path === '/comments');
    expect(read.method).toBe('GET');
    expect(read.query.path).toBe(post);
  });

  test('an empty thread says so, and a failure offers a retry that works', async ({ page }) => {
    await serve(page, { '/capabilities': capabilities, 'GET /comments': { body: { comments: [] } } });
    const thread = await open(page);
    await expect(thread).toHaveAttribute('data-state', 'empty');
    await expect(thread.locator('[data-comments-status]')).toContainText('No comments yet');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, 'GET /comments': { status: 500, body: { error: { code: 'server' } } } });
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-comments-thread]').scrollIntoViewIfNeeded();
    await expect(page.locator('[data-comments-thread]')).toHaveAttribute('data-state', 'error');
    await expect(page.locator('[data-comments-status]')).toHaveAttribute('role', 'alert');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': capabilities, 'GET /comments': { body: { comments } } });
    await page.locator('[data-comments-retry]').click();
    await expect(page.locator('[data-comments-thread]')).toHaveAttribute('data-state', 'loaded');
    await expect(page.locator('[data-comments-list] > li')).toHaveCount(2);
  });

  test('a comment and a reply are posted with the page and land where they belong', async ({ page }) => {
    const calls = await serve(page, {
      '/capabilities': capabilities,
      'GET /comments': { body: { comments } },
      'POST /comments': { status: 201, body: { comment: { id: 'c9', parent_id: null, author: { name: 'Dana' }, body: 'Posted from the test.', created_at: '2026-09-17T09:00:00Z' }, status: 'published' } },
    });
    const thread = await open(page);
    await expect(thread).toHaveAttribute('data-state', 'loaded');

    await page.fill('#comments-name', 'Dana');
    await page.fill('#comments-email', 'dana@example.org');
    await page.fill('#comments-body', 'Posted from the test.');
    await page.click('#comments-form button[type=submit]');
    const form = page.locator('#comments-form');
    await expect(form).toHaveAttribute('data-state', 'success');
    await expect(form.locator('[data-form-status]')).toContainText('Thank you');
    await expect(page.locator('[data-comments-list] > #comment-c9 .comment__body')).toHaveText('Posted from the test.');
    const posted = calls.find((call) => call.method === 'POST');
    expect(posted.headers['idempotency-key']).toMatch(/\S+/);
    expect(posted.body).toEqual({ path: post, parent_id: null, author: { name: 'Dana', email: 'dana@example.org' }, body: 'Posted from the test.' });

    await page.unroute(`${api}**`);
    const replies = await serve(page, {
      '/capabilities': capabilities,
      'POST /comments': { status: 202, body: { comment: { id: 'c10', parent_id: 'c3', author: { name: 'Dana' }, body: 'A reply, held.' }, status: 'pending' } },
    });
    await page.click('#comment-c3 .comment__reply');
    await expect(page.locator('[data-comments-replying]')).toBeVisible();
    await expect(page.locator('[data-comments-replying-to]')).toHaveText('Replying to Cléo');
    await expect(page.locator('#comments-body')).toBeFocused();
    await page.fill('#comments-name', 'Dana');
    await page.fill('#comments-body', 'A reply, held.');
    await page.click('#comments-form button[type=submit]');
    await expect(form.locator('[data-form-status]')).toContainText('waiting');
    const held = page.locator('#comment-c3 > .comments-thread__replies > #comment-c10');
    await expect(held).toHaveClass(/comment--pending/);
    await expect(held.locator('.comment__pending')).toHaveText('Awaiting moderation');
    expect(replies.find((call) => call.method === 'POST').body.parent_id).toBe('c3');
    await expect(page.locator('[data-comments-replying]')).toBeHidden();
  });

  test('the site’s checks and the service’s 422 mark the fields; no feature disables the thread', async ({ page }) => {
    await serve(page, {
      '/capabilities': capabilities,
      'GET /comments': { body: { comments } },
      'POST /comments': { status: 422, body: { error: { code: 'invalid', message: 'Check.', errors: { body: 'Links are not allowed.' } } } },
    });
    const thread = await open(page);
    await expect(thread).toHaveAttribute('data-state', 'loaded');
    await page.click('#comments-form button[type=submit]');
    const form = page.locator('#comments-form');
    await expect(form).toHaveAttribute('data-state', 'invalid');
    await expect(page.locator('#comments-name')).toBeFocused();
    await expect(page.locator('[data-error-for="name"]')).toBeVisible();

    await page.fill('#comments-name', 'Eve');
    await page.fill('#comments-body', 'See https://spam.example');
    await page.click('#comments-form button[type=submit]');
    await expect(page.locator('[data-error-for="body"]')).toHaveText('Links are not allowed.');

    await page.unroute(`${api}**`);
    await serve(page, { '/capabilities': { body: { api_version: '1', features: { comments: false } } } });
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-comments-thread]').scrollIntoViewIfNeeded();
    await expect(page.locator('[data-comments-thread]')).toHaveAttribute('data-state', 'disabled');
    await expect(page.locator('[data-comments-status]')).toContainText('does not offer');
    await expect(page.locator('#comments-form')).toBeHidden();
  });
});
