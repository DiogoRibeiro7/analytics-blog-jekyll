import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError, createClient } from '../../assets/js/dynamic-services/client.js';
import { buildSubscription, initSubscribeForm, initSubscribeForms, validate } from '../../assets/js/subscriptions/form.js';
import { initSubscriptionManage, initSubscriptionManagers, readAction } from '../../assets/js/subscriptions/manage.js';

/**
 * Newsletter subscriptions (#254): the subscribe form and its states, the
 * page the emails link to (confirm, unsubscribe, topics), and the two verbs
 * the client gained for it.
 */

const FORM_LABELS = {
  sending: 'Subscribing…',
  pending: 'Check your inbox.',
  confirmed: 'Subscribed.',
  duplicate: 'Already subscribed.',
  email_invalid: 'Not an email.',
  topics_required: 'Pick one.',
  errors: { invalid: 'Check.', network: 'Unreachable.', rate_limited: 'Wait.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const FORM = `
<section data-subscribe data-subscribe-source="https://example.org/post/" data-subscribe-locale="pt" data-subscribe-double-opt-in="true">
  <script type="application/json" data-subscribe-labels>${JSON.stringify(FORM_LABELS)}</script>
  <form id="subscribe-form-page" novalidate>
    <fieldset>
      <input name="email"><p data-error-for="email" hidden></p>
      <fieldset>
        <input type="checkbox" name="topics" value="new-articles" checked>
        <input type="checkbox" name="topics" value="datasets" checked>
        <p data-error-for="topics" hidden></p>
      </fieldset>
      <input name="website">
    </fieldset>
    <button type="submit">Join</button>
    <p data-form-status hidden></p>
  </form>
</section>`;

const MANAGE_LABELS = {
  confirming: 'Confirming…',
  confirmed: 'Confirmed.',
  invalid_link: 'Link no longer valid.',
  unsubscribing: 'Unsubscribing…',
  unsubscribed: 'Unsubscribed.',
  loading: 'Loading…',
  saving: 'Saving…',
  saved: 'Saved.',
  errors: { network: 'Unreachable.', disabled: 'Off.', unsupported: 'Not offered.' },
};

const MANAGE = `
<section data-subscription-manage data-state="idle" aria-busy="false">
  <script type="application/json" data-manage-labels>${JSON.stringify(MANAGE_LABELS)}</script>
  <p data-manage-status role="status" hidden></p>
  <p data-manage-idle>Open this from an email.</p>
  <div data-manage-unsubscribe-panel hidden><button type="button" data-manage-unsubscribe>Unsubscribe</button></div>
  <form data-manage-preferences hidden novalidate>
    <input type="checkbox" name="topics" value="new-articles">
    <input type="checkbox" name="topics" value="research-notes">
    <input type="checkbox" name="topics" value="datasets">
    <button type="submit">Save</button>
    <button type="button" data-manage-unsubscribe>Unsubscribe</button>
  </form>
</section>`;

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    get: vi.fn().mockResolvedValue({ data: { status: 'confirmed', topics: ['new-articles', 'datasets'] } }),
    post: vi.fn().mockResolvedValue({ data: { status: 'pending' }, requestId: 'req_1' }),
    patch: vi.fn().mockResolvedValue({ data: { topics: ['datasets'] } }),
    delete: vi.fn().mockResolvedValue({ data: null, status: 204 }),
    ...overrides,
  };
}

const flush = async () => {
  for (let turn = 0; turn < 12; turn += 1) {
    await Promise.resolve();
  }
};

afterEach(() => {
  document.body.innerHTML = '';
});

describe('the client', () => {
  it('sends PATCH with a JSON body and DELETE without one', async () => {
    // A Response can be read once, so each call gets its own.
    const fetch = vi.fn().mockImplementation(() =>
      Promise.resolve(new Response('{"ok":true}', { status: 200, headers: { 'Content-Type': 'application/json' } }))
    );
    const client = createClient({ base_url: 'https://api.example.test', api_version: 'v1' }, { fetch });

    await client.patch('/subscriptions/tok', { topics: ['datasets'] });
    await client.delete('/subscriptions/tok');

    const [patchUrl, patchInit] = fetch.mock.calls[0];
    expect(patchUrl).toBe('https://api.example.test/v1/subscriptions/tok');
    expect(patchInit.method).toBe('PATCH');
    expect(JSON.parse(patchInit.body)).toEqual({ topics: ['datasets'] });
    const [, deleteInit] = fetch.mock.calls[1];
    expect(deleteInit.method).toBe('DELETE');
    expect(deleteInit.body).toBeUndefined();
  });
});

describe('the subscription', () => {
  it('carries the address, the topics as a list, the page and the language, without the honeypot', () => {
    const context = { sourceUrl: 'https://example.org/p/', locale: 'en', hasTopics: true };

    expect(buildSubscription({ email: 'a@b.co', topics: 'datasets', website: 'spam' }, context)).toEqual({
      email: 'a@b.co',
      topics: ['datasets'],
      source_url: 'https://example.org/p/',
      locale: 'en',
    });
    expect(buildSubscription({ email: 'a@b.co', topics: ['x', 'y'] }, context).topics).toEqual(['x', 'y']);
    expect(buildSubscription({ email: 'a@b.co' }, context).topics).toEqual([]);
    expect(buildSubscription({ email: 'a@b.co' }, {})).toEqual({ email: 'a@b.co' });
  });

  it('is checked for an address, a topic when the site has topics, and the honeypot', () => {
    expect(validate({ email: 'nope', topics: [] }, {}, FORM_LABELS)).toEqual({ email: 'Not an email.', topics: 'Pick one.' });
    expect(validate({ email: 'a@b.co' }, {}, FORM_LABELS)).toBeNull();
    expect(validate({ email: 'a@b.co', topics: ['x'] }, { website: 'bot' }, FORM_LABELS)).toEqual({ website: 'spam' });
    expect(validate({ email: '' }, {}, {}).email).toContain('email');
  });
});

describe('the subscribe form', () => {
  let root;
  let form;

  beforeEach(() => {
    document.body.innerHTML = FORM;
    root = document.querySelector('[data-subscribe]');
    form = root.querySelector('form');
  });

  it('retries an unchanged submission with its original key, and recovers capability failures', async () => {
    const client = fakeClient();
    client.feature.mockRejectedValueOnce(new ServiceError('network', 'offline'));
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost response'));
    const controller = initSubscribeForm(root, { client });
    form.elements.email.value = 'reader@example.org';
    await controller.submit();
    expect(form.querySelector('button[type=submit]').disabled).toBe(false);
    await controller.submit();
    await controller.submit();
    expect(client.post.mock.calls).toHaveLength(2);
    expect(client.post.mock.calls[1][2].idempotencyKey).toBe(client.post.mock.calls[0][2].idempotencyKey);
    form.elements.email.value = 'reader@example.org';
    await controller.submit();
    expect(client.post.mock.calls[2][2].idempotencyKey).not.toBe(client.post.mock.calls[0][2].idempotencyKey);
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost response'));
    form.elements.email.value = 'reader@example.org';
    await controller.submit();
    form.elements.namedItem('email').value = 'changed@example.org';
    form.elements.namedItem('email').dispatchEvent(new Event('input', { bubbles: true }));
    await controller.submit();
    expect(client.post.mock.calls[4][2].idempotencyKey).not.toBe(client.post.mock.calls[3][2].idempotencyKey);
  });

  it('sends the subscription with an idempotency key and says to check the inbox', async () => {
    const client = fakeClient();
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'reader@example.org';

    const answer = await controller.submit();

    expect(answer.requestId).toBe('req_1');
    expect(client.feature).toHaveBeenCalledWith('subscriptions');
    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/subscriptions');
    expect(payload).toEqual({ email: 'reader@example.org', topics: ['new-articles', 'datasets'], source_url: 'https://example.org/post/', locale: 'pt' });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect([form.dataset.state, form.dataset.result]).toEqual(['success', 'pending']);
    expect(form.querySelector('[data-form-status]').textContent).toBe('Check your inbox.');
    expect(form.elements.namedItem('email').value).toBe('');
  });

  it('takes the page from the canonical link and the language from the document when the markup has neither', async () => {
    delete root.dataset.subscribeSource;
    delete root.dataset.subscribeLocale;
    const link = document.createElement('link');
    link.rel = 'canonical';
    link.href = 'https://example.org/canonical/';
    document.head.appendChild(link);
    document.documentElement.lang = 'es';
    const client = fakeClient();
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'reader@example.org';

    await controller.submit();

    expect(client.post.mock.calls[0][1]).toMatchObject({ source_url: 'https://example.org/canonical/', locale: 'es' });
    link.remove();
    document.documentElement.removeAttribute('lang');
  });

  it('says subscribed when the service confirms at once, or when the site has no double opt-in', async () => {
    const client = fakeClient({ post: vi.fn().mockResolvedValue({ data: { status: 'confirmed' } }) });
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'reader@example.org';
    await controller.submit();
    expect(form.dataset.result).toBe('confirmed');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Subscribed.');

    root.dataset.subscribeDoubleOptIn = 'false';
    const silent = fakeClient({ post: vi.fn().mockResolvedValue({ data: {} }) });
    const second = initSubscribeForm(root, { client: silent });
    form.elements.namedItem('email').value = 'reader@example.org';
    await second.submit();
    expect(form.dataset.result).toBe('confirmed');
  });

  it('treats a duplicate as already subscribed, not as a failure', async () => {
    const client = fakeClient({ post: vi.fn().mockRejectedValue(new ServiceError('conflict', 'x')) });
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'reader@example.org';

    expect(await controller.submit()).toBeNull();
    expect([form.dataset.state, form.dataset.result]).toEqual(['success', 'duplicate']);
    expect(form.querySelector('[data-form-status]').textContent).toBe('Already subscribed.');
  });

  it('marks a bad address or no topic before sending, and the fields a 422 names', async () => {
    const client = fakeClient();
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'not-an-email';
    form.querySelectorAll('[name=topics]').forEach((box) => {
      box.checked = false;
    });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-error-for="email"]').textContent).toBe('Not an email.');
    expect(form.querySelector('[data-error-for="topics"]').textContent).toBe('Pick one.');

    form.elements.namedItem('email').value = 'reader@example.org';
    form.querySelector('[name=topics]').checked = true;
    client.post.mockRejectedValueOnce(new ServiceError('invalid', 'x', { errors: { email: 'This domain cannot receive mail.' } }));
    await controller.submit();
    expect(form.querySelector('[data-error-for="email"]').textContent).toBe('This domain cannot receive mail.');
  });

  it('shows a rate limit and a network failure, keeps the address, and pretends a bot is pending', async () => {
    const client = fakeClient();
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').value = 'reader@example.org';

    client.post.mockRejectedValueOnce(new ServiceError('rate_limited', 'x', { requestId: 'req_9', retryAfter: 60 }));
    await controller.submit();
    expect(form.dataset.state).toBe('error');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Wait. Try again in 60 seconds. Ref req_9');

    client.post.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.submit();
    expect(form.querySelector('[data-form-status]').textContent).toBe('Unreachable.');
    expect(form.elements.namedItem('email').value).toBe('reader@example.org');
    expect(form.dataset.result).toBeUndefined();

    form.elements.namedItem('website').value = 'https://spam.example';
    const calls = client.post.mock.calls.length;
    expect(await controller.submit()).toBeNull();
    expect(client.post.mock.calls.length).toBe(calls);
    expect(form.dataset.result).toBe('pending');
  });

  it('is disabled without a backend or when the service does not take subscriptions, and asks once on first focus', async () => {
    const off = initSubscribeForm(root, { client: fakeClient({ enabled: false }) });
    expect(off.available).toBe(false);
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('button').disabled).toBe(true);

    document.body.innerHTML = FORM;
    root = document.querySelector('[data-subscribe]');
    form = root.querySelector('form');
    const client = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    const controller = initSubscribeForm(root, { client });
    form.elements.namedItem('email').dispatchEvent(new Event('focusin', { bubbles: true }));
    form.elements.namedItem('email').dispatchEvent(new Event('focusin', { bubbles: true }));
    await flush();
    expect(client.feature).toHaveBeenCalledTimes(1);
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Not offered.');

    form.elements.namedItem('email').value = 'reader@example.org';
    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
  });

  it('wires every form on the page', () => {
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { subscriptions: true } };
    const controllers = initSubscribeForms(document);
    expect(controllers).toHaveLength(1);
    const spy = vi.spyOn(controllers[0], 'submit').mockResolvedValue(null);
    form.dispatchEvent(new Event('submit', { cancelable: true }));
    expect(spy).toHaveBeenCalled();
    delete window.DatalogDynamicServices;
  });
});

describe('the link from an email', () => {
  it('names one of the three actions and a URL-safe token, or nothing', () => {
    expect(readAction('?confirm=tok_confirm-123.456~x')).toEqual({ action: 'confirm', token: 'tok_confirm-123.456~x' });
    expect(readAction('?utm=x&unsubscribe=abcdefgh')).toEqual({ action: 'unsubscribe', token: 'abcdefgh' });
    expect(readAction('?manage=abcdefgh12')).toEqual({ action: 'manage', token: 'abcdefgh12' });
    expect(readAction('?confirm=short')).toBeNull();
    expect(readAction('?confirm=<script>alert(1)</script>')).toBeNull();
    expect(readAction('?confirm=has space inside')).toBeNull();
    expect(readAction('?delete=abcdefgh12')).toBeNull();
    expect(readAction('')).toBeNull();
    expect(readAction(undefined)).toBeNull();
  });
});

describe('the manage page', () => {
  let root;

  const open = (search, client = fakeClient()) => {
    document.body.innerHTML = MANAGE;
    root = document.querySelector('[data-subscription-manage]');
    const history = { replaceState: vi.fn() };
    const controller = initSubscriptionManage(root, { client, location: { search, pathname: '/subscriptions/' }, history });
    return { controller, client, history };
  };

  const status = () => root.querySelector('[data-manage-status]');

  it('offers an in-page retry with the retained token after transient failures', async () => {
    for (const action of ['confirm', 'manage', 'unsubscribe']) {
      const client = fakeClient();
      const method = action === 'confirm' ? 'post' : action === 'manage' ? 'get' : 'delete';
      client[method].mockRejectedValueOnce(new ServiceError('network', 'offline'));
      const { controller } = open(`?${action}=abcdefgh12`, client);
      if (action === 'unsubscribe') await controller.unsubscribe();
      await flush();
      const retry = root.querySelector('[data-manage-retry]');
      expect(retry.hidden).toBe(false);
      expect(retry.disabled).toBe(false);
      retry.click();
      await flush();
      expect(client[method]).toHaveBeenCalledTimes(2);
      expect(root.dataset.state).not.toBe('error');
    }
  });

  it('does not call a capabilities 404 an expired subscription link', async () => {
    const client = fakeClient();
    client.feature.mockRejectedValueOnce(new ServiceError('not_found', 'missing service', { status: 404 }));
    open('?confirm=abcdefgh12', client);
    await flush();
    expect(status().textContent).not.toBe('Link no longer valid.');
    expect(client.post).not.toHaveBeenCalled();
  });

  it('explains itself without a link, and says so without a backend', () => {
    const { client, history } = open('');
    expect(root.dataset.state).toBe('idle');
    expect(root.querySelector('[data-manage-idle]').hidden).toBe(false);
    expect(client.post).not.toHaveBeenCalled();
    expect(history.replaceState).not.toHaveBeenCalled();

    open('?confirm=tok_confirm_123', fakeClient({ enabled: false }));
    expect(root.dataset.state).toBe('disabled');
    expect(status().textContent).toBe('Off.');
    expect(root.querySelector('[data-manage-idle]').hidden).toBe(true);
  });

  it('confirms a subscription and takes the token out of the address bar', async () => {
    const { client, history } = open('?confirm=tok_confirm_123');
    await flush();

    expect(history.replaceState).toHaveBeenCalledWith(null, '', '/subscriptions/');
    expect(client.post).toHaveBeenCalledWith('/subscriptions/confirm', { token: 'tok_confirm_123' });
    expect(root.dataset.state).toBe('confirmed');
    expect(status().textContent).toBe('Confirmed.');
  });

  it('says a link is no longer valid for an unknown or expired token', async () => {
    open('?confirm=tok_confirm_123', fakeClient({ post: vi.fn().mockRejectedValue(new ServiceError('not_found', 'x', { status: 404 })) }));
    await flush();
    expect(root.dataset.state).toBe('error');
    expect(status().textContent).toBe('Link no longer valid.');
    expect(status().getAttribute('role')).toBe('alert');

    open('?manage=tok_manage_1234', fakeClient({ get: vi.fn().mockRejectedValue(new ServiceError('http', 'x', { status: 410 })) }));
    await flush();
    expect(status().textContent).toBe('Link no longer valid.');

    open('?manage=tok_manage_1234', fakeClient({ get: vi.fn().mockRejectedValue(new ServiceError('network', 'x')) }));
    await flush();
    expect(status().textContent).toBe('Unreachable.');
  });

  it('ends a subscription only after the button is pressed', async () => {
    const { client } = open('?unsubscribe=tok_unsub_12345');
    await flush();

    expect(client.delete).not.toHaveBeenCalled();
    expect(root.querySelector('[data-manage-unsubscribe-panel]').hidden).toBe(false);

    root.querySelector('[data-manage-unsubscribe-panel] [data-manage-unsubscribe]').click();
    await flush();
    expect(client.delete).toHaveBeenCalledWith('/subscriptions/tok_unsub_12345');
    expect(root.dataset.state).toBe('unsubscribed');
    expect(status().textContent).toBe('Unsubscribed.');
    expect(root.querySelector('[data-manage-unsubscribe-panel]').hidden).toBe(true);
    expect(root.getAttribute('aria-busy')).toBe('false');
  });

  it('loads the topics, saves the change, and can unsubscribe from there', async () => {
    const { client } = open('?manage=tok_manage_1234');
    await flush();

    expect(client.get).toHaveBeenCalledWith('/subscriptions/tok_manage_1234');
    const preferences = root.querySelector('[data-manage-preferences]');
    expect(preferences.hidden).toBe(false);
    expect(Array.from(preferences.querySelectorAll('[name=topics]')).map((box) => box.checked)).toEqual([true, false, true]);

    preferences.querySelector('[value="new-articles"]').checked = false;
    preferences.dispatchEvent(new Event('submit', { cancelable: true }));
    await flush();
    expect(client.patch).toHaveBeenCalledWith('/subscriptions/tok_manage_1234', { topics: ['datasets'] });
    expect(root.dataset.state).toBe('saved');
    expect(status().textContent).toBe('Saved.');

    client.patch.mockRejectedValueOnce(new ServiceError('network', 'x'));
    preferences.dispatchEvent(new Event('submit', { cancelable: true }));
    await flush();
    expect(root.dataset.state).toBe('error');
    expect(preferences.hidden).toBe(false);

    preferences.querySelector('[data-manage-unsubscribe]').click();
    await flush();
    expect(client.delete).toHaveBeenCalledWith('/subscriptions/tok_manage_1234');
    expect(root.dataset.state).toBe('unsubscribed');
  });

  it('wires every manage block on the page', () => {
    document.body.innerHTML = MANAGE;
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { subscriptions: true } };
    const controllers = initSubscriptionManagers(document);
    expect(controllers).toHaveLength(1);
    expect(controllers[0].request).toBeNull();
    delete window.DatalogDynamicServices;
  });
});
