import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  MIN_BODY,
  buildComment,
  initCommentsThread,
  initCommentsThreads,
  renderComment,
  threadOf,
  validate,
} from '../../assets/js/comments/thread.js';

/**
 * The comments thread of the `api` provider (#253): the tree, safe
 * rendering, loading and its states, replies, and posting.
 */

const LABELS = {
  loading: 'Loading…',
  empty: 'Nothing yet.',
  retry: 'Try again',
  reply: 'Reply',
  replying_to: 'Replying to {{name}}',
  anonymous: 'Anonymous',
  pending: 'Awaiting moderation',
  sending: 'Posting…',
  posted: 'Up.',
  posted_pending: 'Waiting.',
  name_required: 'Who?',
  email_invalid: 'Not an email.',
  url_invalid: 'Not a URL.',
  body_short: 'More.',
  errors: { invalid: 'Check.', network: 'Unreachable.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const MARKUP = `
<div data-comments-thread data-comments-path="/post/" data-comments-replies="true" data-state="idle">
  <script type="application/json" data-comments-labels>${JSON.stringify(LABELS)}</script>
  <p data-comments-status role="status">Loading…</p>
  <ol data-comments-list hidden></ol>
  <form id="comments-form" novalidate>
    <p data-comments-replying hidden><span data-comments-replying-to></span><button type="button" data-comments-cancel-reply>Cancel</button></p>
    <fieldset>
      <input name="name"><p data-error-for="name" hidden></p>
      <input name="email"><p data-error-for="email" hidden></p>
      <input name="url"><p data-error-for="url" hidden></p>
      <textarea name="body"></textarea><p data-error-for="body" hidden></p>
      <input type="hidden" name="parent_id" value="">
      <input name="website">
    </fieldset>
    <button type="submit">Post</button>
    <p data-form-status hidden></p>
  </form>
</div>`;

const COMMENTS = [
  { id: 'c2', parent_id: 'c1', author: { name: 'Bob' }, body: 'A reply.', created_at: '2026-09-16T16:00:00Z' },
  { id: 'c1', parent_id: null, author: { name: 'Alice', url: 'https://alice.example' }, body: 'First.\n\n<script>alert(1)</script>', created_at: '2026-09-16T15:30:00Z' },
  { id: 'c3', parent_id: null, author: { name: '', url: 'javascript:alert(1)' }, body: 'Later.', created_at: '2026-09-16T17:00:00Z' },
  { id: 'c4', parent_id: 'gone', author: { name: 'Orphan' }, body: 'Parent deleted.', created_at: '2026-09-16T18:00:00Z' },
];

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    get: vi.fn().mockResolvedValue({ data: { comments: COMMENTS }, requestId: 'req_get' }),
    post: vi.fn().mockResolvedValue({ data: { comment: { id: 'c9', parent_id: null, author: { name: 'Dana' }, body: 'Posted.', created_at: '2026-09-17T09:00:00Z' }, status: 'published' } }),
    ...overrides,
  };
}

function mount() {
  document.body.innerHTML = MARKUP;
  return document.querySelector('[data-comments-thread]');
}

function fill(form, values) {
  Object.entries(values).forEach(([name, value]) => {
    form.elements.namedItem(name).value = value;
  });
}

// Enough microtask turns for a load (capabilities, then the thread) to settle; no timers involved.
const flush = async () => {
  for (let turn = 0; turn < 12; turn += 1) {
    await Promise.resolve();
  }
};

describe('the tree', () => {
  it('nests replies under their parent, oldest first, orphans and flat lists at the top', () => {
    const nested = threadOf(COMMENTS, true);

    expect(nested.map((node) => node.comment.id)).toEqual(['c1', 'c3', 'c4']);
    expect(nested[0].replies.map((node) => node.comment.id)).toEqual(['c2']);
    expect(threadOf(COMMENTS, false).map((node) => node.comment.id)).toEqual(['c1', 'c2', 'c3', 'c4']);
    expect(threadOf(null)).toEqual([]);
    expect(threadOf([null, 'x', { id: 'a' }]).map((node) => node.comment.id)).toEqual(['a']);
  });
});

describe('one comment', () => {
  it('is text only, with a link for an http(s) author and nothing parsed as HTML', () => {
    const item = renderComment(document, COMMENTS[1], { labels: LABELS, replies: true, onReply: () => {} });

    expect(item.id).toBe('comment-c1');
    expect(item.querySelector('script')).toBeNull();
    expect(item.querySelectorAll('.comment__body p')).toHaveLength(2);
    expect(item.querySelector('.comment__body').textContent).toContain('<script>alert(1)</script>');
    const author = item.querySelector('.comment__author');
    expect(author.tagName).toBe('A');
    expect(author.getAttribute('href')).toBe('https://alice.example');
    expect(author.getAttribute('rel')).toBe('nofollow noopener ugc');
    expect(item.querySelector('time').getAttribute('datetime')).toBe('2026-09-16T15:30:00Z');
    expect(item.querySelector('.comment__reply').textContent).toBe('Reply');
  });

  it('keeps an unsafe author link out and names an anonymous author', () => {
    const item = renderComment(document, COMMENTS[2], { labels: LABELS });

    expect(item.querySelector('.comment__author').tagName).toBe('SPAN');
    expect(item.querySelector('.comment__author').textContent).toBe('Anonymous');
    expect(item.querySelector('a')).toBeNull();
    expect(item.querySelector('.comment__reply')).toBeNull();
  });

  it('shows a pending comment with its badge and no reply button', () => {
    const item = renderComment(document, { ...COMMENTS[1], status: 'pending' }, { labels: LABELS, replies: true, onReply: () => {} });

    expect(item.classList.contains('comment--pending')).toBe(true);
    expect(item.querySelector('.comment__pending').textContent).toBe('Awaiting moderation');
    expect(item.querySelector('.comment__reply')).toBeNull();
  });
});

describe('the payload', () => {
  it('is built from the fields and the page, and checked before sending', () => {
    expect(buildComment({ name: 'Dana', email: 'd@example.org', url: 'https://d.example', body: 'Hi there', parent_id: 'c1', website: 'spam' }, '/post/')).toEqual({
      path: '/post/',
      parent_id: 'c1',
      author: { name: 'Dana', email: 'd@example.org', url: 'https://d.example' },
      body: 'Hi there',
    });
    expect(buildComment({}, '/p/')).toEqual({ path: '/p/', parent_id: null, author: { name: '' }, body: '' });

    const bad = buildComment({ email: 'nope', url: 'ftp://x', body: 'a' }, '/p/');
    expect(validate(bad, {}, LABELS)).toEqual({ name: 'Who?', email: 'Not an email.', url: 'Not a URL.', body: 'More.' });
    expect(validate(buildComment({ name: 'D', body: 'x'.repeat(MIN_BODY) }, '/p/'), {}, LABELS)).toBeNull();
    expect(validate(buildComment({ name: 'D', body: 'Hello' }, '/p/'), { website: 'bot' }, LABELS)).toEqual({ website: 'spam' });
  });
});

describe('the thread', () => {
  let root;
  let form;

  beforeEach(() => {
    root = mount();
    form = root.querySelector('form');
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('loads the comments for the page and renders the tree', async () => {
    const client = fakeClient();
    initCommentsThread(root, { client, immediate: true });
    await flush();

    expect(client.feature).toHaveBeenCalledWith('comments');
    expect(client.get).toHaveBeenCalledWith('/comments?path=%2Fpost%2F');
    expect(root.dataset.state).toBe('loaded');
    expect(root.querySelector('[data-comments-status]').hidden).toBe(true);
    const list = root.querySelector('[data-comments-list]');
    expect(list.hidden).toBe(false);
    expect(Array.from(list.children).map((item) => item.id)).toEqual(['comment-c1', 'comment-c3', 'comment-c4']);
    expect(list.querySelector('#comment-c1 > .comments-thread__replies > #comment-c2')).not.toBeNull();
    expect(list.querySelector('script')).toBeNull();
  });

  it('says so when there is nothing, and offers a retry when the service fails', async () => {
    const client = fakeClient({ get: vi.fn().mockResolvedValueOnce({ data: { comments: [] } }) });
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();

    expect(root.dataset.state).toBe('empty');
    expect(root.querySelector('[data-comments-status]').textContent).toBe('Nothing yet.');

    client.get.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.load();
    const status = root.querySelector('[data-comments-status]');
    expect(root.dataset.state).toBe('error');
    expect(status.getAttribute('role')).toBe('alert');
    expect(status.textContent).toContain('Unreachable.');

    client.get.mockResolvedValueOnce({ data: { comments: COMMENTS } });
    status.querySelector('[data-comments-retry]').click();
    await flush();
    expect(root.dataset.state).toBe('loaded');
  });

  it('is disabled, with the form hidden, when the service does not offer comments', async () => {
    const client = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    initCommentsThread(root, { client, immediate: true });
    await flush();

    expect(root.dataset.state).toBe('disabled');
    expect(root.querySelector('[data-comments-status]').textContent).toBe('Not offered.');
    expect(form.hidden).toBe(true);
    expect(client.get).not.toHaveBeenCalled();
  });

  it('posts a comment with an idempotency key and adds it to the list', async () => {
    const client = fakeClient();
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();
    fill(form, { name: 'Dana', email: 'dana@example.org', body: 'Posted.' });

    const answer = await controller.submit();

    expect(answer.data.status).toBe('published');
    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/comments');
    expect(payload).toEqual({ path: '/post/', parent_id: null, author: { name: 'Dana', email: 'dana@example.org' }, body: 'Posted.' });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect(root.querySelector('[data-comments-list] > #comment-c9 .comment__body').textContent).toBe('Posted.');
    expect(form.dataset.state).toBe('success');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Up.');
    expect(form.elements.namedItem('body').value).toBe('');
  });

  it('shows a held comment to its author as awaiting moderation', async () => {
    const client = fakeClient({
      post: vi.fn().mockResolvedValue({ data: { comment: { id: 'c10', parent_id: null, author: { name: 'Eve' }, body: 'Held.' }, status: 'pending' } }),
    });
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();
    fill(form, { name: 'Eve', body: 'Held.' });

    await controller.submit();

    const item = root.querySelector('#comment-c10');
    expect(item.classList.contains('comment--pending')).toBe(true);
    expect(item.querySelector('.comment__pending').textContent).toBe('Awaiting moderation');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Waiting.');
  });

  it('replies under the parent, and the reply can be cancelled', async () => {
    const client = fakeClient({
      post: vi.fn().mockResolvedValue({ data: { comment: { id: 'c11', parent_id: 'c3', author: { name: 'Fay' }, body: 'Reply.' }, status: 'published' } }),
    });
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();

    root.querySelector('#comment-c3 .comment__reply').click();
    expect(form.elements.namedItem('parent_id').value).toBe('c3');
    expect(root.querySelector('[data-comments-replying]').hidden).toBe(false);
    expect(root.querySelector('[data-comments-replying-to]').textContent).toBe('Replying to Anonymous');
    expect(document.activeElement).toBe(form.elements.namedItem('body'));

    root.querySelector('[data-comments-cancel-reply]').click();
    expect(form.elements.namedItem('parent_id').value).toBe('');
    expect(root.querySelector('[data-comments-replying]').hidden).toBe(true);

    root.querySelector('#comment-c3 .comment__reply').click();
    fill(form, { name: 'Fay', body: 'Reply.' });
    await controller.submit();

    expect(client.post.mock.calls[0][1].parent_id).toBe('c3');
    expect(root.querySelector('#comment-c3 > .comments-thread__replies > #comment-c11')).not.toBeNull();
    expect(form.elements.namedItem('parent_id').value).toBe('');
  });

  it('marks the fields the site or the service refuses, and keeps the text on a failure', async () => {
    const client = fakeClient();
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();
    fill(form, { email: 'nope', body: 'a' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-error-for="name"]').textContent).toBe('Who?');
    expect(form.querySelector('[data-error-for="body"]').textContent).toBe('More.');

    fill(form, { name: 'Gil', email: '', body: 'Fine text.' });
    client.post.mockRejectedValueOnce(new ServiceError('invalid', 'x', { errors: { body: 'Too long.' } }));
    await controller.submit();
    expect(form.querySelector('[data-error-for="body"]').textContent).toBe('Too long.');

    client.post.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.submit();
    expect(form.dataset.state).toBe('error');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Unreachable.');
    expect(form.elements.namedItem('body').value).toBe('Fine text.');
  });

  it('pretends a bot is awaiting moderation and sends nothing', async () => {
    const client = fakeClient();
    const controller = initCommentsThread(root, { client, immediate: true });
    await flush();
    fill(form, { name: 'Bot', body: 'Buy now.', website: 'https://spam.example' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('success');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Waiting.');
  });

  it('waits for the section to come near before loading, and wires every thread', async () => {
    let callback;
    const observe = vi.fn();
    const disconnect = vi.fn();
    const win = {
      IntersectionObserver: function FakeObserver(handler) {
        callback = handler;
        return { observe, disconnect };
      },
    };
    const client = fakeClient();
    initCommentsThread(root, { client, window: win });

    expect(observe).toHaveBeenCalledWith(root);
    expect(client.get).not.toHaveBeenCalled();
    callback([{ isIntersecting: true }]);
    await flush();
    expect(disconnect).toHaveBeenCalled();
    expect(client.get).toHaveBeenCalledTimes(1);

    document.body.innerHTML = '';
    root = mount();
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { comments: true } };
    const controllers = initCommentsThreads(document);
    expect(controllers).toHaveLength(1);
    expect(typeof controllers[0].load).toBe('function');
    delete window.DatalogDynamicServices;
  });
});
