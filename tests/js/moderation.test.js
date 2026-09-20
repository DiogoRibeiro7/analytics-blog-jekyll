import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  ACTIONS,
  QUEUE,
  RESULT,
  actionsFor,
  buildQuery,
  initModerationInbox,
  initModerationInboxes,
  normalizeItem,
  renderItem,
} from '../../assets/js/moderation/inbox.js';

/**
 * The moderation inbox (#257): what an entry becomes, the actions open to
 * it, the listing and its filters, signed-out and not-allowed answers, the
 * approve / spam / accept / resolve / reject workflows, and failing safely.
 */

const LABELS = {
  loading: 'Loading…',
  empty: 'Nothing here.',
  working: 'Working…',
  done: 'Done: {{action}}.',
  unauthorized: 'Not signed in.',
  forbidden: 'Not a moderator.',
  link_required: 'Give a link.',
  note: 'Note',
  link: 'Link',
  in_reply_to: 'In reply to',
  types: { comment: 'Comment', correction: 'Correction report', abuse: 'Abuse report' },
  statuses: { pending: 'Pending', approved: 'Approved', new: 'New', accepted: 'Accepted', resolved: 'Resolved', spam: 'Spam' },
  actions: { approve: 'Approve', spam: 'Mark as spam', delete: 'Delete', accept: 'Accept', reject: 'Reject', resolve: 'Resolve', reviewed: 'Mark reviewed' },
  categories: { code: 'Outdated or broken code' },
  errors: { server: 'The service failed.', conflict: 'Someone acted first.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const MARKUP = `
<section data-moderation-inbox data-moderation-site="https://example.org" data-moderation-credentials="include" data-state="idle">
  <script type="application/json" data-moderation-labels>${JSON.stringify(LABELS)}</script>
  <form data-moderation-filters>
    <select name="type"><option value="">All</option><option value="comment">Comments</option></select>
    <select name="status"><option value="">Queue</option><option value="spam">Spam</option><option value="approved">Approved</option></select>
    <input name="path"><input name="q">
    <button type="submit">Apply</button><button type="reset">Reset</button>
  </form>
  <p data-moderation-status role="status" hidden></p>
  <p data-moderation-sign-in hidden><a href="https://api.example.org/login">Sign in</a></p>
  <ol data-moderation-list></ol>
  <button type="button" data-moderation-more hidden>More</button>
</section>`;

const COMMENT = {
  id: 'c_81',
  type: 'comment',
  status: 'pending',
  created_at: '2026-09-18T09:12:00Z',
  path: '/post/',
  title: 'A Post',
  author: { name: 'Alice', email: 'alice@example.org' },
  body: 'Does it hold?\n\n<img src=x onerror=alert(1)>',
  context: { parent: { author: { name: 'Bob' }, body: 'It did for us.' } },
  history: [],
};

const REPORT = {
  id: 'r_17',
  type: 'correction',
  status: 'new',
  created_at: '2026-09-17T16:40:00Z',
  path: '/post/',
  category: 'code',
  section: 'checklist',
  quote: 'Cluster on purchase_ts',
  message: 'The table clusters on customer_id.',
  author: { email: 'reader@example.org' },
  history: [{ action: 'reviewed', at: '2026-09-17T18:00:00Z', moderator: 'diogo', note: 'Checking.' }],
};

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    get: vi.fn().mockResolvedValue({ data: { items: [COMMENT, REPORT, { id: 'x', type: 'unknown' }, null] } }),
    post: vi.fn().mockImplementation((path, payload) =>
      Promise.resolve({ data: { item: { ...(path.includes('c_81') ? COMMENT : REPORT), status: RESULT[payload.action] } } })
    ),
    ...overrides,
  };
}

const flush = async () => {
  for (let turn = 0; turn < 14; turn += 1) {
    await Promise.resolve();
  }
};

let root;

function mount() {
  document.body.innerHTML = MARKUP;
  root = document.querySelector('[data-moderation-inbox]');
  return root;
}

const ids = () => Array.from(root.querySelectorAll('[data-moderation-list] > li')).map((item) => item.dataset.itemId);
const statusText = () => root.querySelector('[data-moderation-status]').textContent;
const press = (id, action) => root.querySelector(`[data-item-id="${id}"] [data-moderation-action="${action}"]`).click();

afterEach(() => {
  document.body.innerHTML = '';
});

describe('an entry', () => {
  it('is kept with its fields as text, or dropped without an id or a known type', () => {
    const item = normalizeItem(REPORT);

    expect(item).toMatchObject({ id: 'r_17', type: 'correction', status: 'new', category: 'code', body: 'The table clusters on customer_id.' });
    expect(item.history).toEqual([{ action: 'reviewed', at: '2026-09-17T18:00:00Z', moderator: 'diogo', note: 'Checking.' }]);
    expect(normalizeItem(COMMENT).parent).toEqual({ author: 'Bob', body: 'It did for us.' });
    expect(normalizeItem({ ...REPORT, resolution: { url: 'javascript:alert(1)' } }).link).toBe('');
    expect(normalizeItem({ ...REPORT, resolution: { url: 'https://github.com/x/y/pull/1' } }).link).toBe('https://github.com/x/y/pull/1');
    expect(normalizeItem({ type: 'comment' })).toBeNull();
    expect(normalizeItem({ id: 1, type: 'subscriber' })).toBeNull();
    expect(normalizeItem('text')).toBeNull();
    expect(normalizeItem(null)).toBeNull();
  });

  it('offers the actions its type and status allow, and none once decided', () => {
    expect(actionsFor({ type: 'comment', status: 'pending' })).toEqual(['approve', 'spam', 'delete']);
    expect(actionsFor({ type: 'correction', status: 'accepted' })).toEqual(['resolve', 'reject']);
    expect(actionsFor({ type: 'abuse', status: 'open' })).toEqual(['dismiss', 'hide', 'delete']);
    expect(actionsFor({ type: 'comment', status: 'deleted' })).toEqual([]);
    expect(actionsFor({ type: 'correction', status: 'resolved' })).toEqual([]);
    Object.values(ACTIONS).forEach((byStatus) =>
      Object.values(byStatus).flat().forEach((action) => expect(RESULT[action]).toBeTruthy())
    );
    expect(QUEUE.correction).toContain('accepted');
  });

  it('is rendered as text, with a link only to a path on the site', () => {
    const item = renderItem(document, normalizeItem(COMMENT), { labels: LABELS, siteUrl: 'https://example.org/', onAction: () => {} });

    expect(item.querySelector('img')).toBeNull();
    expect(item.querySelector('.moderation-item__body').textContent).toContain('<img src=x onerror=alert(1)>');
    expect(item.querySelector('.moderation-item__where a').getAttribute('href')).toBe('https://example.org/post/');
    expect(item.querySelector('.moderation-item__author').textContent).toBe('Alice · alice@example.org');
    expect(item.querySelector('.moderation-item__context').textContent).toContain('In reply to Bob');
    expect(Array.from(item.querySelectorAll('[data-moderation-action]')).map((button) => button.textContent)).toEqual(['Approve', 'Mark as spam', 'Delete']);
    expect(item.querySelector('label[for="moderation-note-c_81"]').textContent).toBe('Note');

    const elsewhere = renderItem(document, normalizeItem({ ...COMMENT, path: '//evil.example/x' }), { labels: LABELS });
    expect(elsewhere.querySelector('.moderation-item__where a').hasAttribute('href')).toBe(false);
    expect(elsewhere.querySelector('[data-moderation-action]')).toBeNull();

    const report = renderItem(document, normalizeItem(REPORT), { labels: LABELS, siteUrl: 'https://example.org', onAction: () => {} });
    expect(report.querySelector('.moderation-item__where a').getAttribute('href')).toBe('https://example.org/post/#checklist');
    expect(report.querySelector('.moderation-item__category').textContent).toBe('Outdated or broken code');
    expect(report.querySelector('.moderation-item__history li').textContent).toContain('Mark reviewed · diogo');
  });
});

describe('a listing', () => {
  it('asks for the filters that are set, and the cursor', () => {
    expect(buildQuery({})).toBe('');
    expect(buildQuery({ type: 'comment', status: '', path: ' /post/ ', q: 'skew' })).toBe('?type=comment&path=%2Fpost%2F&q=skew');
    expect(buildQuery({ status: 'spam' }, 'abc')).toBe('?status=spam&cursor=abc');
    expect(buildQuery({ status: 'all' })).toBe('');
  });
});

describe('the inbox', () => {
  beforeEach(() => {
    mount();
  });

  it.each([false, true])('refreshes a stale response after approval, preserving pagination (append=%s)', async (append) => {
    let finishRead;
    const client = fakeClient({ get: vi.fn().mockResolvedValueOnce({ data: { items: [COMMENT], next_cursor: 'page2' } }) });
    const controller = initModerationInbox(root, { client });
    await flush();
    client.get.mockImplementationOnce(() => new Promise((resolve) => { finishRead = resolve; }));
    client.get.mockResolvedValueOnce({ data: { items: [REPORT] } });
    const refresh = controller.load(append);
    await flush();
    await controller.act(normalizeItem(COMMENT), 'approve');
    expect(ids()).toEqual([]);

    // Editing an unapplied filter must not change the read being retried.
    root.querySelector('[name=status]').value = 'spam';
    finishRead({ data: { items: [COMMENT] } });
    await refresh;
    expect(ids()).toEqual(['r_17']);
    expect(client.get).toHaveBeenLastCalledWith(append ? '/moderation/items?cursor=page2' : '/moderation/items');
    expect(root.getAttribute('aria-busy')).toBe('false');
    expect(root.querySelector('[data-moderation-more]').hidden).toBe(true);
  });

  it('updates the replacement row when a refresh completes before approval', async () => {
    let finishPost;
    const client = fakeClient({ post: vi.fn().mockImplementationOnce(() => new Promise((resolve) => { finishPost = resolve; })) });
    const controller = initModerationInbox(root, { client });
    await flush();
    const action = controller.act(normalizeItem(COMMENT), 'approve');
    await flush();
    await controller.load();
    finishPost({ data: { item: { ...COMMENT, status: 'approved' } } });
    await action;
    expect(ids()).toEqual(['r_17']);
  });

  it('does not let a stale read failure erase a completed moderation action', async () => {
    let failRead;
    const client = fakeClient();
    const controller = initModerationInbox(root, { client });
    await flush();
    client.get.mockImplementationOnce(() => new Promise((_resolve, reject) => { failRead = reject; }));
    client.get.mockResolvedValueOnce({ data: { items: [REPORT] } });
    const refresh = controller.load();
    await flush();
    await controller.act(normalizeItem(COMMENT), 'approve');
    failRead(new ServiceError('server', 'Old read failed'));
    await refresh;
    expect(ids()).toEqual(['r_17']);
    expect(root.dataset.state).toBe('loaded');
  });

  it('loads the queue, drops what it does not know, and reloads under the filters', async () => {
    const client = fakeClient();
    initModerationInbox(root, { client });
    await flush();

    expect(client.feature).toHaveBeenCalledWith('moderation');
    expect(client.get).toHaveBeenCalledWith('/moderation/items');
    expect(root.dataset.state).toBe('loaded');
    expect(ids()).toEqual(['c_81', 'r_17']);

    root.querySelector('[name=status]').value = 'spam';
    root.querySelector('[name=q]').value = 'casino';
    root.querySelector('[data-moderation-filters]').dispatchEvent(new Event('submit', { cancelable: true }));
    await flush();
    expect(client.get).toHaveBeenLastCalledWith('/moderation/items?status=spam&q=casino');
  });

  it('says so when the queue is empty, and continues from the cursor', async () => {
    const client = fakeClient({ get: vi.fn().mockResolvedValueOnce({ data: { items: [] } }) });
    const controller = initModerationInbox(root, { client });
    await flush();
    expect(root.dataset.state).toBe('empty');
    expect(statusText()).toBe('Nothing here.');

    client.get.mockResolvedValueOnce({ data: { items: [COMMENT], next_cursor: 'next1' } });
    await controller.load();
    const more = root.querySelector('[data-moderation-more]');
    expect(more.hidden).toBe(false);

    client.get.mockResolvedValueOnce({ data: { items: [REPORT] } });
    more.click();
    await flush();
    expect(client.get).toHaveBeenLastCalledWith('/moderation/items?cursor=next1');
    expect(ids()).toEqual(['c_81', 'r_17']);
    expect(more.hidden).toBe(true);
  });

  it('shows a way to sign in on a 401 and says so on a 403, with no item on the page', async () => {
    initModerationInbox(root, { client: fakeClient({ get: vi.fn().mockRejectedValue(new ServiceError('unauthorized', 'x', { status: 401 })) }) });
    await flush();
    expect(root.dataset.state).toBe('unauthorized');
    expect(statusText()).toBe('Not signed in.');
    expect(root.querySelector('[data-moderation-status]').getAttribute('role')).toBe('alert');
    expect(root.querySelector('[data-moderation-sign-in]').hidden).toBe(false);
    expect(ids()).toEqual([]);

    mount();
    initModerationInbox(root, { client: fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('forbidden', 'x', { status: 403 })) }) });
    await flush();
    expect(root.dataset.state).toBe('forbidden');
    expect(statusText()).toBe('Not a moderator.');
    expect(root.querySelector('[data-moderation-sign-in]').hidden).toBe(true);

    mount();
    initModerationInbox(root, { client: fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) }) });
    await flush();
    expect(root.dataset.state).toBe('disabled');

    mount();
    initModerationInbox(root, { client: fakeClient({ enabled: false }) });
    expect(root.dataset.state).toBe('disabled');
    expect(statusText()).toBe('Off.');
  });

  it('approves a comment with a note and an idempotency key, and takes it out of the queue', async () => {
    const client = fakeClient();
    initModerationInbox(root, { client });
    await flush();

    root.querySelector('#moderation-note-c_81').value = 'Fine.';
    press('c_81', 'approve');
    expect(root.querySelector('[data-item-id="c_81"]').getAttribute('aria-busy')).toBe('true');
    await flush();

    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/moderation/items/c_81/actions');
    expect(payload).toEqual({ action: 'approve', note: 'Fine.' });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect(ids()).toEqual(['r_17']);
    expect(statusText()).toBe('Done: Approve.');
  });

  it('marks spam and rejects, leaving an empty queue announced', async () => {
    const client = fakeClient();
    initModerationInbox(root, { client });
    await flush();

    press('c_81', 'spam');
    await flush();
    press('r_17', 'reject');
    await flush();

    expect(client.post.mock.calls.map((call) => call[1].action)).toEqual(['spam', 'reject']);
    expect(ids()).toEqual([]);
    expect(root.dataset.state).toBe('empty');
    expect(statusText()).toBe('Done: Reject. Nothing here.');
  });

  it('keeps an accepted report in the queue until it is resolved with a link', async () => {
    const client = fakeClient();
    initModerationInbox(root, { client });
    await flush();

    press('r_17', 'accept');
    await flush();
    const accepted = root.querySelector('[data-item-id="r_17"]');
    expect(accepted.dataset.itemStatus).toBe('accepted');
    expect(accepted.querySelector('[data-item-message]').textContent).toBe('Done: Accept.');
    expect(Array.from(accepted.querySelectorAll('[data-moderation-action]')).map((button) => button.dataset.moderationAction)).toEqual(['resolve', 'reject']);

    press('r_17', 'resolve');
    await flush();
    expect(client.post).toHaveBeenCalledTimes(1);
    expect(accepted.querySelector('[data-item-message]').textContent).toBe('Give a link.');

    accepted.querySelector('#moderation-link-r_17').value = 'javascript:alert(1)';
    press('r_17', 'resolve');
    await flush();
    expect(client.post).toHaveBeenCalledTimes(1);

    accepted.querySelector('#moderation-link-r_17').value = 'https://github.com/example/site/pull/42';
    press('r_17', 'resolve');
    await flush();
    expect(client.post.mock.calls[1][1]).toEqual({ action: 'resolve', link: 'https://github.com/example/site/pull/42' });
    expect(ids()).toEqual(['c_81']);
  });

  it('leaves the item as it was when the service fails or someone acted first', async () => {
    const client = fakeClient();
    initModerationInbox(root, { client });
    await flush();

    client.post.mockRejectedValueOnce(new ServiceError('server', 'x', { status: 500, requestId: 'req_5' }));
    press('c_81', 'approve');
    await flush();
    const item = root.querySelector('[data-item-id="c_81"]');
    expect(ids()).toEqual(['c_81', 'r_17']);
    expect(item.dataset.itemStatus).toBe('pending');
    expect(item.getAttribute('aria-busy')).toBe('false');
    expect(item.querySelector('[data-item-message]').textContent).toBe('The service failed. Ref req_5');
    expect(item.querySelector('[data-item-message]').getAttribute('role')).toBe('alert');
    expect(Array.from(item.querySelectorAll('button')).every((button) => !button.disabled)).toBe(true);

    client.post.mockRejectedValueOnce(new ServiceError('conflict', 'x', { status: 409 }));
    press('c_81', 'approve');
    await flush();
    expect(item.querySelector('[data-item-message]').textContent).toBe('Someone acted first.');

    client.post.mockRejectedValueOnce(new ServiceError('unauthorized', 'x', { status: 401 }));
    press('c_81', 'approve');
    await flush();
    expect(root.dataset.state).toBe('unauthorized');
    expect(ids()).toEqual([]);
  });

  it('builds a client that sends the session, at the endpoint the page names', () => {
    root.dataset.moderationEndpoint = 'https://moderation.example.org/';
    const controller = initModerationInbox(root);

    expect(controller.client.base).toBe('https://moderation.example.org');
    expect(controller.client.credentials).toBe('include');
    expect(initModerationInboxes(document)).toHaveLength(1);
  });
});

describe('patch moderation regressions', () => {
  it('uses an explicit endpoint even when the main service opts out of moderation', async () => {
    mount();
    window.DatalogDynamicServices = { base_url: 'https://api.example.org', features: { moderation: false } };
    root.dataset.moderationEndpoint = 'https://moderation.example.org';
    vi.stubGlobal('fetch', vi.fn((url) => Promise.resolve(new Response(JSON.stringify(
      url.endsWith('/capabilities') ? { api_version: 'v1', features: { moderation: true } } : { items: [COMMENT] }
    ), { status: 200 }))));
    const controller = initModerationInbox(root);
    await controller.load();
    expect(ids()).toEqual([COMMENT.id]);
    expect(fetch.mock.calls[0][0]).toBe('https://moderation.example.org/v1/capabilities');
    delete window.DatalogDynamicServices;
  });

  it('reuses a failed action key and keeps the last applied filters until resubmission', async () => {
    mount();
    const client = fakeClient();
    const controller = initModerationInbox(root, { client });
    await flush();
    root.querySelector('[name=status]').value = 'approved';
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost'));
    await controller.act(normalizeItem(COMMENT), 'approve');
    await controller.act(normalizeItem(COMMENT), 'approve');
    expect(client.post.mock.calls[1][2].idempotencyKey).toBe(client.post.mock.calls[0][2].idempotencyKey);
    expect(ids()).not.toContain(COMMENT.id);
  });
  it('discards stale filter requests', async () => {
    mount();
    const reads = [];
    const client = fakeClient({ get: vi.fn(() => new Promise((resolve) => reads.push(resolve))) });
    const controller = initModerationInbox(root, { client });
    await flush();
    root.querySelector('[name=status]').value = 'spam';
    const latest = controller.load();
    await flush();
    reads[1]({ data: { items: [{ ...COMMENT, id: 'spam', status: 'spam' }] } });
    await latest;
    reads[0]({ data: { items: [COMMENT] } });
    await flush();
    expect(ids()).toEqual(['spam']);
  });
});
