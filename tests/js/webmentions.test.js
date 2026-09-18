import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  DEFAULT_TYPES,
  MAX_EXCERPT,
  initAllWebmentions,
  initWebmentions,
  mentionsIn,
  normalizeMention,
  renderMention,
} from '../../assets/js/webmentions/list.js';

/**
 * "Mentioned elsewhere" (#258): what the service's entries become, what is
 * dropped as unverified or unsafe, text-only rendering, and the states.
 */

const LABELS = {
  loading: 'Looking…',
  empty: 'Nothing yet.',
  retry: 'Try again',
  types: { mention: 'Mention', reply: 'Reply', repost: 'Repost', like: 'Like' },
  errors: { network: 'Unreachable.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const MARKUP = `
<section data-webmentions data-webmentions-target="https://blog.example.org/post/" data-webmentions-types="mention,reply,repost" data-state="idle">
  <script type="application/json" data-webmentions-labels>${JSON.stringify(LABELS)}</script>
  <p data-webmentions-status role="status">Looking…</p>
  <ul data-webmentions-list hidden></ul>
</section>`;

const GOOD = {
  id: 'm1',
  source: 'https://example.org/article',
  target: 'https://blog.example.org/post/',
  type: 'reply',
  author: { name: 'Jane Doe', url: 'https://example.org' },
  title: 'A response to the article',
  excerpt: 'I tried the bootstrap on a smaller sample and…',
  published_at: '2026-09-16T14:00:00Z',
  verified: true,
};

const ENTRIES = [
  GOOD,
  { ...GOOD, id: 'm2', type: 'mention', title: '<script>alert(1)</script> cites this', published_at: '2026-09-17T09:00:00Z', author: { name: 'Bot', url: 'javascript:alert(1)' } },
  { ...GOOD, id: 'm3', verified: false },
  { ...GOOD, id: 'm4', source: 'ftp://example.org/x' },
  { ...GOOD, id: 'm5', type: 'like' },
  { ...GOOD, id: 'm6', published_at: 'yesterday', title: '', excerpt: 'x'.repeat(500) },
  'not an entry',
  null,
];

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    get: vi.fn().mockResolvedValue({ data: { mentions: ENTRIES } }),
    ...overrides,
  };
}

function mount() {
  document.body.innerHTML = MARKUP;
  return document.querySelector('[data-webmentions]');
}

const flush = async () => {
  for (let turn = 0; turn < 12; turn += 1) {
    await Promise.resolve();
  }
};

describe('an entry', () => {
  it('is kept when verified, from an http(s) source and of a listed type, with its text trimmed and cut', () => {
    const mention = normalizeMention(GOOD, ['mention', 'reply']);

    expect(mention).toMatchObject({ id: 'm1', source: 'https://example.org/article', host: 'example.org', type: 'reply', title: 'A response to the article' });
    expect(mention.author).toEqual({ name: 'Jane Doe', url: 'https://example.org' });
    expect(normalizeMention({ ...GOOD, excerpt: 'x'.repeat(500) }).excerpt).toHaveLength(MAX_EXCERPT);
    expect(normalizeMention({ ...GOOD, title: '  spaced   out \n title ' }).title).toBe('spaced out title');
    expect(normalizeMention({ ...GOOD, type: undefined }).type).toBe('mention');
    expect(normalizeMention({ ...GOOD, published_at: 'yesterday' }).published_at).toBe('');
    expect(normalizeMention({ ...GOOD, author: { name: 'X', url: 'javascript:alert(1)' } }).author.url).toBe('');
    expect(normalizeMention({ ...GOOD, source: 'https://www.example.org/a' }).host).toBe('example.org');
  });

  it('is dropped when unverified, without an http(s) source, of an unlisted type, or not an object', () => {
    expect(normalizeMention({ ...GOOD, verified: false })).toBeNull();
    expect(normalizeMention({ ...GOOD, verified: 'true' })).toBeNull();
    expect(normalizeMention({ ...GOOD, source: 'javascript:alert(1)' })).toBeNull();
    expect(normalizeMention({ ...GOOD, source: undefined })).toBeNull();
    expect(normalizeMention({ ...GOOD, type: 'like' }, DEFAULT_TYPES)).toBeNull();
    expect(normalizeMention('text')).toBeNull();
    expect(normalizeMention(null)).toBeNull();
    expect(normalizeMention([GOOD])).toBeNull();
  });

  it('is listed newest first, and a malformed answer gives an empty list', () => {
    expect(mentionsIn({ mentions: ENTRIES }, ['mention', 'reply', 'repost']).map((mention) => mention.id)).toEqual(['m2', 'm1', 'm6']);
    expect(mentionsIn({ mentions: 'lots' })).toEqual([]);
    expect(mentionsIn({})).toEqual([]);
    expect(mentionsIn('<html>')).toEqual([]);
    expect(mentionsIn(null)).toEqual([]);
  });

  it('is rendered as text, with the source and author links carrying nofollow', () => {
    const item = renderMention(document, normalizeMention(ENTRIES[1], ['mention']), { labels: LABELS });

    expect(item.className).toBe('webmention webmention--mention');
    expect(item.dataset.mentionId).toBe('m2');
    expect(item.querySelector('script')).toBeNull();
    expect(item.querySelector('.webmention__type').textContent).toBe('Mention');
    const link = item.querySelector('.webmention__title');
    expect(link.textContent).toBe('<script>alert(1)</script> cites this');
    expect(link.getAttribute('href')).toBe('https://example.org/article');
    expect(link.getAttribute('rel')).toBe('nofollow noopener ugc');
    expect(item.querySelector('.webmention__author').tagName).toBe('SPAN');
    expect(item.querySelector('.webmention__host').textContent).toBe('example.org');
    expect(item.querySelector('time').getAttribute('datetime')).toBe('2026-09-17T09:00:00Z');

    const titled = renderMention(document, normalizeMention(GOOD, ['reply']), { labels: LABELS });
    expect(titled.querySelector('.webmention__author').getAttribute('href')).toBe('https://example.org');
    expect(titled.querySelector('.webmention__excerpt').textContent).toBe(GOOD.excerpt);

    const bare = renderMention(document, normalizeMention({ ...GOOD, title: '', excerpt: '', author: {}, published_at: '' }, ['reply']), { labels: LABELS });
    expect(bare.querySelector('.webmention__title').textContent).toBe('example.org');
    expect(bare.querySelector('.webmention__meta')).toBeNull();
    expect(bare.querySelector('.webmention__excerpt')).toBeNull();
  });
});

describe('the section', () => {
  let root;

  beforeEach(() => {
    root = mount();
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('loads the mentions of the page, keeps only the listed kinds and shows them newest first', async () => {
    const client = fakeClient();
    const controller = initWebmentions(root, { client, immediate: true });
    await flush();

    expect(controller.types).toEqual(['mention', 'reply', 'repost']);
    expect(client.feature).toHaveBeenCalledWith('webmentions');
    expect(client.get).toHaveBeenCalledWith('/webmentions?target=https%3A%2F%2Fblog.example.org%2Fpost%2F');
    expect(root.dataset.state).toBe('loaded');
    expect(root.querySelector('[data-webmentions-status]').hidden).toBe(true);
    const list = root.querySelector('[data-webmentions-list]');
    expect(list.hidden).toBe(false);
    expect(Array.from(list.children).map((item) => item.dataset.mentionId)).toEqual(['m2', 'm1', 'm6']);
    expect(list.querySelector('script')).toBeNull();
  });

  it('says so when there is nothing, also for a malformed answer', async () => {
    const client = fakeClient({ get: vi.fn().mockResolvedValue({ data: { mentions: [] } }) });
    initWebmentions(root, { client, immediate: true });
    await flush();
    expect(root.dataset.state).toBe('empty');
    expect(root.querySelector('[data-webmentions-status]').textContent).toBe('Nothing yet.');
    expect(root.querySelector('[data-webmentions-list]').hidden).toBe(true);

    root = mount();
    initWebmentions(root, { client: fakeClient({ get: vi.fn().mockResolvedValue({ data: '<html>' }) }), immediate: true });
    await flush();
    expect(root.dataset.state).toBe('empty');
  });

  it('offers a retry when the service fails, and hides itself when the service does not offer mentions', async () => {
    const client = fakeClient({
      get: vi.fn().mockRejectedValueOnce(new ServiceError('network', 'x')).mockResolvedValue({ data: { mentions: ENTRIES } }),
    });
    initWebmentions(root, { client, immediate: true });
    await flush();
    const status = root.querySelector('[data-webmentions-status]');
    expect(root.dataset.state).toBe('error');
    expect(status.getAttribute('role')).toBe('alert');
    expect(status.textContent).toContain('Unreachable.');

    status.querySelector('[data-webmentions-retry]').click();
    await flush();
    expect(root.dataset.state).toBe('loaded');

    root = mount();
    const off = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    initWebmentions(root, { client: off, immediate: true });
    await flush();
    expect(root.dataset.state).toBe('disabled');
    expect(root.hidden).toBe(true);
    expect(off.get).not.toHaveBeenCalled();
  });

  it('falls back to the default kinds when the markup names none it knows', async () => {
    root.dataset.webmentionsTypes = 'unknown, reply ';
    const controller = initWebmentions(root, { client: fakeClient(), immediate: true });
    await flush();
    expect(controller.types).toEqual(['reply']);

    root = mount();
    delete root.dataset.webmentionsTypes;
    expect(initWebmentions(root, { client: fakeClient(), immediate: true }).types).toEqual(DEFAULT_TYPES);
  });

  it('waits for the section to come near before reading, and wires every section', async () => {
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
    initWebmentions(root, { client, window: win });

    expect(observe).toHaveBeenCalledWith(root);
    expect(client.get).not.toHaveBeenCalled();
    callback([{ isIntersecting: true }]);
    await flush();
    expect(disconnect).toHaveBeenCalled();
    expect(client.get).toHaveBeenCalledTimes(1);

    document.body.innerHTML = '';
    root = mount();
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { webmentions: true } };
    const controllers = initAllWebmentions(document);
    expect(controllers).toHaveLength(1);
    expect(typeof controllers[0].load).toBe('function');
    delete window.DatalogDynamicServices;
  });
});
