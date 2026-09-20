import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  DEFAULT_TIMEOUT,
  ServiceError,
  createClient,
  describeError,
  getClient,
  parseRetryAfter,
  readConfig,
  resetClient,
  versionSegment,
} from '../../assets/js/dynamic-services/client.js';
import { applyFieldErrors, readForm, setFormState, showFailure } from '../../assets/js/dynamic-services/form-state.js';

/**
 * The dynamic-services contract (#259): the client's URLs, JSON, timeouts,
 * retries, the one error shape, capability discovery and the version
 * mismatch, and the shared form states.
 */

const CONFIG = { base_url: 'https://api.example.org/', api_version: 'v1', timeout_ms: 50, features: { corrections: true, comments: false } };

function reply(status, body, headers = {}) {
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(headers),
    text: () => Promise.resolve(text),
  };
}

function client(fetchImpl, overrides = {}) {
  return createClient({ ...CONFIG, ...overrides }, { fetch: fetchImpl, delay: () => Promise.resolve(), document: null });
}

describe('addresses and settings', () => {
  it('builds versioned URLs and feature paths from the public settings', () => {
    const c = client(vi.fn());

    expect(c.enabled).toBe(true);
    expect(c.version).toBe('v1');
    expect(c.urlFor('/corrections')).toBe('https://api.example.org/v1/corrections');
    expect(c.urlFor('capabilities')).toBe('https://api.example.org/v1/capabilities');
    expect(c.urlFor('https://elsewhere.example/x')).toBe('https://elsewhere.example/x');
    expect(c.pathFor('corrections')).toBe('/corrections');
    expect(client(vi.fn(), { paths: { corrections: '/feedback/corrections' } }).pathFor('corrections')).toBe('/feedback/corrections');
    expect(versionSegment(2)).toBe('v2');
    expect(versionSegment('V3')).toBe('v3');
    expect(versionSegment(undefined)).toBe('v1');
    expect(client(vi.fn(), { timeout_ms: 'no' }).timeout).toBe(DEFAULT_TIMEOUT);
    expect(client(vi.fn(), { credentials: 'weird' }).credentials).toBe('omit');
  });

  it('is disabled without a base URL and reads the page settings', async () => {
    const off = createClient({}, { fetch: vi.fn() });

    expect(off.enabled).toBe(false);
    await expect(off.get('/x')).rejects.toMatchObject({ kind: 'disabled', retryable: false });
    await expect(off.feature('corrections')).rejects.toMatchObject({ kind: 'disabled' });

    window.DatalogDynamicServices = { base_url: 'https://api.example.org' };
    expect(readConfig(window).base_url).toBe('https://api.example.org');
    resetClient();
    expect(getClient().base).toBe('https://api.example.org');
    expect(getClient()).toBe(getClient());
    delete window.DatalogDynamicServices;
    resetClient();
    expect(readConfig(window)).toEqual({});
  });
});

describe('requests', () => {
  it('sends and reads JSON with the headers the contract names', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(reply(201, { id: 7 }, { 'X-Request-Id': 'req_1' }));
    const c = client(fetchImpl, { credentials: 'include' });

    const result = await c.post('/corrections', { message: 'hi' }, { idempotencyKey: 'key-1' });

    expect(result).toMatchObject({ data: { id: 7 }, status: 201, requestId: 'req_1' });
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe('https://api.example.org/v1/corrections');
    expect(init.method).toBe('POST');
    expect(init.credentials).toBe('include');
    expect(init.headers).toMatchObject({ Accept: 'application/json', 'Content-Type': 'application/json', 'Idempotency-Key': 'key-1' });
    expect(init.body).toBe('{"message":"hi"}');
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('sends the CSRF cookie in the header on writes only', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(reply(200, {}));
    const doc = { cookie: 'other=1; csrf_token=abc%20def' };
    const c = createClient({ ...CONFIG, csrf_header: 'X-CSRF-Token', csrf_cookie: 'csrf_token' }, { fetch: fetchImpl, document: doc });

    await c.post('/x', {});
    await c.get('/x');

    expect(fetchImpl.mock.calls[0][1].headers['X-CSRF-Token']).toBe('abc def');
    expect(fetchImpl.mock.calls[1][1].headers['X-CSRF-Token']).toBeUndefined();
  });

  it('times out through AbortController and retries a read, not a write', async () => {
    vi.useFakeTimers();
    const fetchImpl = vi.fn((url, init) => new Promise((resolve, reject) => {
      init.signal.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
    }));
    const c = client(fetchImpl);

    // The expectation is attached before the clock moves, so the rejection is never unhandled.
    const read = expect(c.get('/slow')).rejects.toMatchObject({ kind: 'timeout', retryable: true });
    await vi.advanceTimersByTimeAsync(200);
    await read;
    expect(fetchImpl).toHaveBeenCalledTimes(3);

    fetchImpl.mockClear();
    const write = expect(c.post('/slow', {})).rejects.toMatchObject({ kind: 'timeout' });
    await vi.advanceTimersByTimeAsync(200);
    await write;
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('reports the caller’s own abort as such', async () => {
    const controller = new AbortController();
    const fetchImpl = vi.fn((url, init) => new Promise((resolve, reject) => {
      init.signal.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
    }));
    const c = client(fetchImpl);
    const pending = c.get('/x', { signal: controller.signal });
    controller.abort();

    await expect(pending).rejects.toMatchObject({ kind: 'aborted', retryable: false });
  });

  it('retries a network failure for a read and gives up after two more tries', async () => {
    const fetchImpl = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));
    const c = client(fetchImpl);

    await expect(c.get('/x')).rejects.toMatchObject({ kind: 'network' });
    expect(fetchImpl).toHaveBeenCalledTimes(3);

    fetchImpl.mockClear();
    fetchImpl.mockRejectedValueOnce(new TypeError('Failed to fetch')).mockResolvedValueOnce(reply(200, { ok: true }));
    await expect(c.get('/x')).resolves.toMatchObject({ data: { ok: true } });
  });

  it('turns a 2xx that is not JSON into a malformed error, and reads an empty body as null', async () => {
    const c = client(vi.fn().mockResolvedValueOnce(reply(200, '<html>', { 'X-Request-Id': 'req_9' })).mockResolvedValueOnce(reply(204, '')));

    await expect(c.get('/x')).rejects.toMatchObject({ kind: 'malformed', status: 200, requestId: 'req_9', retryable: false });
    await expect(c.get('/x')).resolves.toMatchObject({ data: null, status: 204 });
  });

  it('normalizes the statuses the contract names', async () => {
    const cases = [
      [401, 'unauthorized', false],
      [403, 'forbidden', false],
      [404, 'not_found', false],
      [409, 'conflict', false],
      [418, 'http', false],
      [503, 'server', true],
    ];
    for (const [status, kind, retryable] of cases) {
      const c = client(vi.fn().mockResolvedValue(reply(status, { error: { code: `e${status}`, message: `m${status}` } })));
      await expect(c.post('/x', {})).rejects.toMatchObject({ kind, status, code: `e${status}`, message: `m${status}`, retryable });
    }
    const bare = client(vi.fn().mockResolvedValue(reply(500, 'oops')));
    await expect(bare.post('/x', {})).rejects.toMatchObject({ kind: 'server', message: 'The service answered 500' });
  });

  it('carries a 422’s field errors', async () => {
    const body = { error: { code: 'invalid', message: 'Check the fields.', errors: { message: 'Too short.' } }, request_id: 'r' };
    const c = client(vi.fn().mockResolvedValue(reply(422, body)));
    const error = await c.post('/x', {}).catch((failure) => failure);

    expect(error).toBeInstanceOf(ServiceError);
    expect(error).toMatchObject({ kind: 'invalid', status: 422, errors: { message: 'Too short.' }, retryable: false });
  });

  it('waits for Retry-After on a 429 read, and does not wait an hour', async () => {
    const waits = [];
    const fetchImpl = vi.fn()
      .mockResolvedValueOnce(reply(429, {}, { 'Retry-After': '2' }))
      .mockResolvedValueOnce(reply(200, { ok: true }));
    const c = createClient(CONFIG, { fetch: fetchImpl, delay: (ms) => { waits.push(ms); return Promise.resolve(); }, document: null });

    await expect(c.get('/x')).resolves.toMatchObject({ data: { ok: true } });
    expect(waits).toEqual([2000]);

    const later = client(vi.fn().mockResolvedValue(reply(429, {}, { 'Retry-After': '3600' })));
    await expect(later.get('/x')).rejects.toMatchObject({ kind: 'rate_limited', retryAfter: 3600 });
    expect(parseRetryAfter('bogus')).toBeNull();
    expect(parseRetryAfter(new Date(Date.now() + 5000).toUTCString())).toBeGreaterThanOrEqual(4);
  });

  it('retries a 5xx read and never a write', async () => {
    const fetchImpl = vi.fn().mockResolvedValueOnce(reply(502, {})).mockResolvedValueOnce(reply(200, { ok: true }));
    const c = client(fetchImpl);

    await expect(c.get('/x')).resolves.toMatchObject({ data: { ok: true } });
    expect(fetchImpl).toHaveBeenCalledTimes(2);

    fetchImpl.mockClear();
    fetchImpl.mockResolvedValue(reply(502, {}));
    await expect(c.post('/x', {})).rejects.toMatchObject({ kind: 'server' });
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });
});

describe('discovery', () => {
  it('fetches the capabilities once and answers whether a feature can be used', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(reply(200, { api_version: '1', features: { corrections: true, reactions: false } }));
    const c = client(fetchImpl);

    await expect(c.feature('corrections')).resolves.toBe(true);
    await expect(c.feature('reactions')).rejects.toMatchObject({ kind: 'unsupported' });
    await expect(c.feature('comments')).rejects.toMatchObject({ kind: 'disabled' });
    await expect(c.capabilities()).resolves.toMatchObject({ api_version: '1' });
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    expect(fetchImpl.mock.calls[0][0]).toBe('https://api.example.org/v1/capabilities');
  });

  it('reports an API version mismatch clearly and forgets a failed discovery', async () => {
    const fetchImpl = vi.fn()
      .mockResolvedValueOnce(reply(200, { api_version: '2', features: { corrections: true } }))
      .mockResolvedValueOnce(reply(200, { api_version: 'v1', features: { corrections: true } }));
    const c = client(fetchImpl);

    await expect(c.feature('corrections')).rejects.toMatchObject({ kind: 'version', expected: '1', actual: '2', retryable: false });
    await expect(c.feature('corrections')).resolves.toBe(true);
    expect(fetchImpl).toHaveBeenCalledTimes(2);
  });
});

describe('messages', () => {
  it('describes an error for a reader, with the request reference', () => {
    const error = new ServiceError('rate_limited', 'x', { requestId: 'req_5' });

    expect(describeError(error)).toBe('Too many requests for now. Please wait a little and try again. Reference: req_5');
    expect(describeError(error, { rate_limited: 'Espera.', reference: 'Ref {{id}}' })).toBe('Espera. Ref req_5');
    expect(describeError(new Error('plain'))).toBe('The service refused the request.');
    expect(describeError(new ServiceError('nonsense', 'x'), { http: 'Nope.' })).toBe('Nope.');
  });
});

describe('form states', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <form id="report">
        <fieldset>
          <label>Message <textarea name="message"></textarea></label>
          <p data-error-for="message" hidden></p>
          <label>Email <input name="contact_email" value=" a@b.c "></label>
          <p data-error-for="contact_email" hidden></p>
          <input type="checkbox" name="agree" value="yes">
          <input type="checkbox" name="tags" value="a" checked><input type="checkbox" name="tags" value="b" checked>
        </fieldset>
        <button type="submit">Send</button>
        <p data-form-status hidden></p>
      </form>`;
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('marks pending, success and disabled states on the form', () => {
    const form = document.querySelector('form');
    const button = form.querySelector('button');
    const status = form.querySelector('[data-form-status]');

    setFormState(form, 'pending', 'Sending…');
    expect(form.dataset.state).toBe('pending');
    expect(form.getAttribute('aria-busy')).toBe('true');
    expect(button.disabled).toBe(true);
    expect(status.textContent).toBe('Sending…');
    expect(status.getAttribute('role')).toBe('status');

    setFormState(form, 'success', 'Thanks.');
    expect(button.disabled).toBe(false);
    expect(form.getAttribute('aria-busy')).toBe('false');

    setFormState(form, 'disabled', 'Off.');
    expect(form.querySelector('fieldset').disabled).toBe(true);
    expect(button.disabled).toBe(true);

    setFormState(form, 'nonsense');
    expect(form.dataset.state).toBe('idle');
    expect(status.hidden).toBe(true);
  });

  it('shows a 422’s errors next to the fields and clears them on the next state', () => {
    const form = document.querySelector('form');
    const field = form.elements.message;

    showFailure(form, new ServiceError('invalid', 'x', { errors: { message: ['Too short.', 'Say more.'], unknown: 'ignored' } }));

    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-form-status]').getAttribute('role')).toBe('alert');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(field.getAttribute('aria-describedby')).toBe('report-message-error');
    expect(form.querySelector('[data-error-for="message"]').textContent).toBe('Too short. Say more.');
    expect(document.activeElement).toBe(field);

    setFormState(form, 'idle');
    expect(field.hasAttribute('aria-invalid')).toBe(false);
    expect(field.hasAttribute('aria-describedby')).toBe(false);
    expect(form.querySelector('[data-error-for="message"]').hidden).toBe(true);
    expect(applyFieldErrors(form, {})).toBe(0);
  });

  it('shows any other failure as an error with the reader’s message', () => {
    const form = document.querySelector('form');

    showFailure(form, new ServiceError('rate_limited', 'x', { requestId: 'req_2' }), { rate_limited: 'Wait.' });

    expect(form.dataset.state).toBe('error');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Wait. Reference: req_2');
  });

  it('reads the fields as trimmed strings, lists and left-out checkboxes', () => {
    const form = document.querySelector('form');
    form.elements.message.value = '  hello  ';

    expect(readForm(form)).toEqual({ message: 'hello', contact_email: 'a@b.c', tags: ['a', 'b'] });
  });
});

describe('patch client regressions', () => {
  it('supports a same-origin root endpoint and body request ids', async () => {
    const fetch = vi.fn().mockResolvedValue(reply(422, { request_id: 'body-id', error: { message: 'bad' } }));
    const c = client(fetch, { base_url: '/' });
    expect(c.enabled).toBe(true);
    await expect(c.post('/contact', {})).rejects.toMatchObject({ requestId: 'body-id' });
    expect(fetch.mock.calls[0][0]).toBe('/v1/contact');
  });
  it('does not fetch with an already aborted signal', async () => {
    const fetch = vi.fn();
    const controller = new AbortController();
    controller.abort();
    await expect(client(fetch).get('/x', { signal: controller.signal })).rejects.toMatchObject({ kind: 'aborted' });
    expect(fetch).not.toHaveBeenCalled();
  });
  it('includes translated retry timing', () => {
    expect(describeError(new ServiceError('rate_limited', 'x', { retryAfter: 12 }), { rate_limited: 'Wait.', retry_after: 'Retry in {{seconds}} s.' })).toBe('Wait. Retry in 12 s.');
  });
});
