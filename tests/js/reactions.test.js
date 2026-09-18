import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  STORAGE_PREFIX,
  countsIn,
  initAllReactions,
  initReactions,
  storeChoice,
  storedChoice,
} from '../../assets/js/reactions/widget.js';

/**
 * Article reactions (#255): counts only from the service, the reader's own
 * choice remembered on their device, and every state of a read and a send.
 */

const LABELS = {
  sending: 'Sending…',
  thanks: 'Counted.',
  already: 'Already counted.',
  errors: { network: 'Unreachable.', rate_limited: 'Wait.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const MARKUP = `
<section data-reactions data-reactions-path="/post/" data-reactions-counts="true" data-state="idle" aria-busy="false">
  <script type="application/json" data-reactions-labels>${JSON.stringify(LABELS)}</script>
  <p id="reactions-prompt">Was this useful?</p>
  <div role="group">
    <button type="button" data-reaction="useful" aria-pressed="false"><span>Useful</span><span data-reaction-count hidden></span></button>
    <button type="button" data-reaction="clear" aria-pressed="false"><span>Clear</span><span data-reaction-count hidden></span></button>
    <button type="button" data-reaction="needs-clarification" aria-pressed="false"><span>Needs clarification</span><span data-reaction-count hidden></span></button>
  </div>
  <p data-reactions-status role="status" hidden></p>
</section>`;

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    get: vi.fn().mockResolvedValue({ data: { counts: { useful: 42, 'needs-clarification': 3 } } }),
    post: vi.fn().mockResolvedValue({ data: { counts: { useful: 43, 'needs-clarification': 3 }, reaction: 'useful' } }),
    ...overrides,
  };
}

function memoryStorage(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    getItem: (key) => (store.has(key) ? store.get(key) : null),
    setItem: (key, value) => store.set(key, String(value)),
    store,
  };
}

function mount() {
  document.body.innerHTML = MARKUP;
  return document.querySelector('[data-reactions]');
}

const counts = (root) =>
  Object.fromEntries(
    Array.from(root.querySelectorAll('[data-reaction]')).map((button) => {
      const slot = button.querySelector('[data-reaction-count]');
      return [button.dataset.reaction, slot.hidden ? null : slot.textContent];
    })
  );

const pressed = (root) => Array.from(root.querySelectorAll('[aria-pressed="true"]')).map((button) => button.dataset.reaction);

const flush = async () => {
  for (let turn = 0; turn < 12; turn += 1) {
    await Promise.resolve();
  }
};

describe('the counts and the stored choice', () => {
  it('keeps only non-negative integers keyed by reaction, and nothing from a malformed answer', () => {
    expect(countsIn({ counts: { useful: 42, clear: 0, bad: -1, text: '7', float: 1.5 } })).toEqual({ useful: 42, clear: 0 });
    expect(countsIn({ counts: [] })).toBeNull();
    expect(countsIn({ counts: 'lots' })).toBeNull();
    expect(countsIn({})).toBeNull();
    expect(countsIn(null)).toBeNull();
    expect(countsIn('<html>')).toBeNull();
  });

  it('remembers the choice per page and survives a storage that throws', () => {
    const storage = memoryStorage();
    storeChoice(storage, '/a/', 'useful');

    expect(storedChoice(storage, '/a/')).toBe('useful');
    expect(storedChoice(storage, '/b/')).toBeNull();
    expect(storage.store.get(`${STORAGE_PREFIX}/a/`)).toBe('useful');

    const broken = { getItem: () => { throw new Error('blocked'); }, setItem: () => { throw new Error('full'); } };
    expect(() => storeChoice(broken, '/a/', 'clear')).not.toThrow();
    expect(storedChoice(broken, '/a/')).toBeNull();
    expect(storedChoice(null, '/a/')).toBeNull();
  });
});

describe('the strip', () => {
  let root;

  beforeEach(() => {
    root = mount();
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('shows the counts the service has and nothing for the rest', async () => {
    const client = fakeClient();
    initReactions(root, { client, storage: memoryStorage(), immediate: true });
    await flush();

    expect(client.feature).toHaveBeenCalledWith('reactions');
    expect(client.get).toHaveBeenCalledWith('/reactions?path=%2Fpost%2F');
    expect(root.dataset.state).toBe('loaded');
    expect(counts(root)).toEqual({ useful: '42', clear: null, 'needs-clarification': '3' });
    expect(pressed(root)).toEqual([]);
  });

  it('hides every count when the site asks, when the answer is malformed, or when the service cannot be read', async () => {
    root.dataset.reactionsCounts = 'false';
    initReactions(root, { client: fakeClient(), storage: memoryStorage(), immediate: true });
    await flush();
    expect(counts(root)).toEqual({ useful: null, clear: null, 'needs-clarification': null });
    expect(root.dataset.state).toBe('loaded');

    root = mount();
    initReactions(root, { client: fakeClient({ get: vi.fn().mockResolvedValue({ data: '<html>' }) }), storage: memoryStorage(), immediate: true });
    await flush();
    expect(counts(root)).toEqual({ useful: null, clear: null, 'needs-clarification': null });
    expect(root.dataset.state).toBe('loaded');

    root = mount();
    initReactions(root, { client: fakeClient({ get: vi.fn().mockRejectedValue(new ServiceError('network', 'x')) }), storage: memoryStorage(), immediate: true });
    await flush();
    expect(root.dataset.state).toBe('unavailable');
    expect(counts(root)).toEqual({ useful: null, clear: null, 'needs-clarification': null });
    expect(root.querySelector('[data-reactions-status]').hidden).toBe(true);
    expect(Array.from(root.querySelectorAll('button')).every((button) => !button.disabled)).toBe(true);
  });

  it('is disabled, with a message, when the service does not offer reactions', async () => {
    const client = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    initReactions(root, { client, storage: memoryStorage(), immediate: true });
    await flush();

    expect(root.dataset.state).toBe('disabled');
    expect(root.querySelector('[data-reactions-status]').textContent).toBe('Not offered.');
    expect(Array.from(root.querySelectorAll('button')).every((button) => button.disabled)).toBe(true);
    expect(client.get).not.toHaveBeenCalled();
  });

  it('sends a reaction with an idempotency key, marks it, remembers it and shows the counts the service returns', async () => {
    const client = fakeClient();
    const storage = memoryStorage();
    const controller = initReactions(root, { client, storage, immediate: true });
    await flush();

    root.querySelector('[data-reaction="useful"]').click();
    expect(root.dataset.state).toBe('pending');
    expect(root.getAttribute('aria-busy')).toBe('true');
    await flush();

    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/reactions');
    expect(payload).toEqual({ path: '/post/', reaction: 'useful' });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect(root.dataset.state).toBe('selected');
    expect(root.getAttribute('aria-busy')).toBe('false');
    expect(pressed(root)).toEqual(['useful']);
    expect(controller.selected).toBe('useful');
    expect(storage.store.get(`${STORAGE_PREFIX}/post/`)).toBe('useful');
    expect(counts(root)).toEqual({ useful: '43', clear: null, 'needs-clarification': '3' });
    expect(root.querySelector('[data-reactions-status]').textContent).toBe('Counted.');

    expect(await controller.react('useful')).toBeNull();
    expect(client.post).toHaveBeenCalledTimes(1);
    expect(root.querySelector('[data-reactions-status]').textContent).toBe('Already counted.');
    expect(await controller.react('nonsense')).toBeNull();
  });

  it('leaves the counts alone when the service returns none, rather than inventing one', async () => {
    const client = fakeClient({ post: vi.fn().mockResolvedValue({ data: { status: 'received' } }) });
    const controller = initReactions(root, { client, storage: memoryStorage(), immediate: true });
    await flush();

    await controller.react('clear');

    expect(pressed(root)).toEqual(['clear']);
    expect(counts(root)).toEqual({ useful: '42', clear: null, 'needs-clarification': '3' });
  });

  it('shows the remembered choice on the next visit', async () => {
    const storage = memoryStorage({ [`${STORAGE_PREFIX}/post/`]: 'needs-clarification' });
    const controller = initReactions(root, { client: fakeClient(), storage, immediate: true });

    expect(pressed(root)).toEqual(['needs-clarification']);
    expect(controller.selected).toBe('needs-clarification');
    await flush();
    expect(pressed(root)).toEqual(['needs-clarification']);
  });

  it('treats a conflict as already counted, and a rate limit or a failure as an error that changes nothing', async () => {
    const client = fakeClient();
    const storage = memoryStorage();
    const controller = initReactions(root, { client, storage, immediate: true });
    await flush();

    client.post.mockRejectedValueOnce(new ServiceError('conflict', 'x'));
    expect(await controller.react('useful')).toBeNull();
    expect(pressed(root)).toEqual(['useful']);
    expect(storage.store.get(`${STORAGE_PREFIX}/post/`)).toBe('useful');
    expect(root.querySelector('[data-reactions-status]').textContent).toBe('Already counted.');

    client.post.mockRejectedValueOnce(new ServiceError('rate_limited', 'x', { requestId: 'req_9', retryAfter: 30 }));
    await controller.react('clear');
    const status = root.querySelector('[data-reactions-status]');
    expect(status.textContent).toBe('Wait. Ref req_9');
    expect(status.getAttribute('role')).toBe('alert');
    expect(pressed(root)).toEqual(['useful']);
    expect(root.dataset.state).toBe('loaded');

    client.post.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.react('clear');
    expect(status.textContent).toBe('Unreachable.');
    expect(pressed(root)).toEqual(['useful']);
    expect(Array.from(root.querySelectorAll('button')).every((button) => !button.disabled)).toBe(true);

    client.post.mockRejectedValueOnce(new ServiceError('disabled', 'x'));
    await controller.react('clear');
    expect(root.dataset.state).toBe('disabled');
    expect(Array.from(root.querySelectorAll('button')).every((button) => button.disabled)).toBe(true);
  });

  it('waits for the strip to come near before reading, and wires every strip', async () => {
    let callback;
    const observe = vi.fn();
    const disconnect = vi.fn();
    const win = {
      IntersectionObserver: function FakeObserver(handler) {
        callback = handler;
        return { observe, disconnect };
      },
      localStorage: memoryStorage(),
    };
    const client = fakeClient();
    initReactions(root, { client, window: win });

    expect(observe).toHaveBeenCalledWith(root);
    expect(client.get).not.toHaveBeenCalled();
    callback([{ isIntersecting: true }]);
    await flush();
    expect(disconnect).toHaveBeenCalled();
    expect(client.get).toHaveBeenCalledTimes(1);

    document.body.innerHTML = '';
    root = mount();
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { reactions: true } };
    const controllers = initAllReactions(document);
    expect(controllers).toHaveLength(1);
    expect(typeof controllers[0].react).toBe('function');
    delete window.DatalogDynamicServices;
  });
});
