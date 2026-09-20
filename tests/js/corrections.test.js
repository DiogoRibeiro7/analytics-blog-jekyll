import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  MIN_MESSAGE,
  buildReport,
  fillSections,
  initCorrectionReport,
  initCorrectionReports,
  selectedQuote,
  validate,
} from '../../assets/js/corrections/form.js';

/**
 * The correction-report form (#256): what it sends, what it checks before
 * sending, and every state a submission can end in.
 */

const LABELS = {
  pending: 'Sending…',
  success: 'Thank you.',
  message_short: 'At least {{min}} characters.',
  email_invalid: 'Not an email.',
  errors: { invalid: 'Check the fields.', network: 'Unreachable.', rate_limited: 'Wait.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const MARKUP = `
<div class="post-content"><h2 id="intro">Introduction</h2><p>The quick brown fox.</p><h3 id="detail">Detail</h3></div>
<details data-correction-report data-article-url="https://example.org/post/" data-article-title="A Post">
  <summary>Report</summary>
  <script type="application/json" data-correction-labels>${JSON.stringify(LABELS)}</script>
  <form id="report" novalidate>
    <p data-correction-quote hidden></p>
    <fieldset>
      <select name="category"><option value="code">Code</option><option value="typo">Typo</option></select>
      <select name="section"><option value="">Anywhere</option></select>
      <textarea name="message"></textarea><p data-error-for="message" hidden></p>
      <input name="contact_email"><p data-error-for="contact_email" hidden></p>
      <input type="hidden" name="quote" value="">
      <input name="website">
    </fieldset>
    <button type="submit">Send</button>
    <p data-form-status hidden></p>
  </form>
</details>`;

function fakeClient(overrides = {}) {
  return {
    enabled: true,
    pathFor: (feature) => `/${feature}`,
    feature: vi.fn().mockResolvedValue(true),
    post: vi.fn().mockResolvedValue({ data: { status: 'received' }, requestId: 'req_1' }),
    ...overrides,
  };
}

function mount() {
  document.body.innerHTML = MARKUP;
  return document.querySelector('[data-correction-report]');
}

function fill(form, values) {
  Object.entries(values).forEach(([name, value]) => {
    form.elements.namedItem(name).value = value;
  });
}

describe('the report', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('fills the section list from the article headings', () => {
    const root = mount();
    const select = root.querySelector('[name=section]');
    fillSections(select, document.querySelector('.post-content'));

    expect(Array.from(select.options).map((option) => [option.value, option.textContent])).toEqual([
      ['', 'Anywhere'],
      ['intro', 'Introduction'],
      ['detail', 'Detail'],
    ]);
    expect(() => fillSections(null, null)).not.toThrow();
  });

  it('takes the selected text when it is in the article', () => {
    mount();
    const content = document.querySelector('.post-content');
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(content.querySelector('p'));
    selection.removeAllRanges();
    selection.addRange(range);

    expect(selectedQuote(window, content)).toBe('The quick brown fox.');
    selection.removeAllRanges();
    expect(selectedQuote(window, content)).toBe('');
    expect(selectedQuote({ getSelection: () => null }, content)).toBe('');
  });

  it('builds the payload from the fields and the article, without the honeypot', () => {
    const fields = { category: 'code', section: 'intro', message: 'x', contact_email: 'a@b.c', quote: 'q', website: 'spam' };

    expect(buildReport(fields, { url: 'https://example.org/p/', title: 'P' })).toEqual({
      category: 'code',
      message: 'x',
      article: { url: 'https://example.org/p/', title: 'P' },
      section: 'intro',
      contact_email: 'a@b.c',
      quote: 'q',
    });
    expect(buildReport({}, { url: 'u', title: 't' })).toEqual({ category: 'other', message: '', article: { url: 'u', title: 't' } });
  });

  it('checks the message length, the email and the honeypot before sending', () => {
    const report = buildReport({ message: 'too short', contact_email: 'nope' }, { url: 'u', title: 't' });

    expect(validate(report, {}, LABELS)).toEqual({ message: `At least ${MIN_MESSAGE} characters.`, contact_email: 'Not an email.' });
    expect(validate(buildReport({ message: 'x'.repeat(20) }, { url: 'u', title: 't' }), {}, LABELS)).toBeNull();
    expect(validate(buildReport({ message: 'x'.repeat(20) }, { url: 'u', title: 't' }), { website: 'bot' }, LABELS)).toEqual({ website: 'spam' });
    expect(validate(report, {}, {}).message).toContain('20');
  });
});

describe('the form', () => {
  let root;
  let form;

  beforeEach(() => {
    root = mount();
    form = root.querySelector('form');
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('retries an unchanged submission with its original key, and recovers capability failures', async () => {
    const client = fakeClient();
    client.feature.mockRejectedValueOnce(new ServiceError('network', 'offline'));
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost response'));
    const controller = initCorrectionReport(root, { client });
    fill(form, { message: 'A sufficiently detailed correction report.' });
    await controller.submit();
    expect(form.querySelector('button[type=submit]').disabled).toBe(false);
    await controller.submit();
    await controller.submit();
    expect(client.post.mock.calls).toHaveLength(2);
    expect(client.post.mock.calls[1][2].idempotencyKey).toBe(client.post.mock.calls[0][2].idempotencyKey);
    fill(form, { message: 'A sufficiently detailed correction report.' });
    await controller.submit();
    expect(client.post.mock.calls[2][2].idempotencyKey).not.toBe(client.post.mock.calls[0][2].idempotencyKey);
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost response'));
    fill(form, { message: 'A sufficiently detailed correction report.' });
    await controller.submit();
    form.elements.namedItem('message').value += 'x';
    form.elements.namedItem('message').dispatchEvent(new Event('input', { bubbles: true }));
    await controller.submit();
    expect(client.post.mock.calls[4][2].idempotencyKey).not.toBe(client.post.mock.calls[3][2].idempotencyKey);
  });

  it('sends a valid report with an idempotency key and shows success', async () => {
    const client = fakeClient();
    const controller = initCorrectionReport(root, { client });
    fill(form, { category: 'typo', section: 'intro', message: 'The fox is described as brown but the figure shows red.', contact_email: 'reader@example.org' });

    const answer = await controller.submit();

    expect(answer).toMatchObject({ requestId: 'req_1' });
    expect(client.feature).toHaveBeenCalledWith('corrections');
    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/corrections');
    expect(payload).toEqual({
      category: 'typo',
      section: 'intro',
      message: 'The fox is described as brown but the figure shows red.',
      contact_email: 'reader@example.org',
      article: { url: 'https://example.org/post/', title: 'A Post' },
    });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect(form.dataset.state).toBe('success');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Thank you.');
    expect(form.elements.namedItem('message').value).toBe('');
  });

  it('sends nothing for a short message or a bad email and marks the fields', async () => {
    const client = fakeClient();
    const controller = initCorrectionReport(root, { client });
    fill(form, { message: 'Too short.', contact_email: 'not-an-email' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('invalid');
    expect(form.elements.namedItem('message').getAttribute('aria-invalid')).toBe('true');
    expect(form.querySelector('[data-error-for="message"]').textContent).toBe(`At least ${MIN_MESSAGE} characters.`);
    expect(form.querySelector('[data-error-for="contact_email"]').textContent).toBe('Not an email.');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Check the fields.');
  });

  it('pretends a bot succeeded and sends nothing', async () => {
    const client = fakeClient();
    const controller = initCorrectionReport(root, { client });
    fill(form, { message: 'x'.repeat(30), website: 'https://spam.example' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('success');
  });

  it('shows the service’s field errors, a rate limit and a network failure', async () => {
    const client = fakeClient();
    const controller = initCorrectionReport(root, { client });
    fill(form, { message: 'x'.repeat(30) });

    client.post.mockRejectedValueOnce(new ServiceError('invalid', 'x', { errors: { message: 'Be specific.' } }));
    expect(await controller.submit()).toBeNull();
    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-error-for="message"]').textContent).toBe('Be specific.');

    client.post.mockRejectedValueOnce(new ServiceError('rate_limited', 'x', { requestId: 'req_9', retryAfter: 60 }));
    await controller.submit();
    expect(form.dataset.state).toBe('error');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Wait. Try again in 60 seconds. Ref req_9');
    expect(form.querySelector('[data-form-status]').getAttribute('role')).toBe('alert');

    client.post.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.submit();
    expect(form.querySelector('[data-form-status]').textContent).toBe('Unreachable.');
    expect(form.querySelector('button').disabled).toBe(false);
  });

  it('is disabled when the site has no backend or the service does not take reports', async () => {
    const off = initCorrectionReport(root, { client: fakeClient({ enabled: false }) });

    expect(off.available).toBe(false);
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('button').disabled).toBe(true);
    expect(form.querySelector('[data-form-status]').textContent).toBe('Off.');

    root = mount();
    form = root.querySelector('form');
    const client = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    const controller = initCorrectionReport(root, { client });
    fill(form, { message: 'x'.repeat(30) });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Not offered.');
    expect(form.querySelector('button').disabled).toBe(true);
  });

  it('asks the service once when the form opens and attaches the selected text', async () => {
    const client = fakeClient();
    initCorrectionReport(root, { client });
    const content = document.querySelector('.post-content');
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(content.querySelector('p'));
    selection.removeAllRanges();
    selection.addRange(range);

    root.open = true;
    root.dispatchEvent(new Event('toggle'));
    root.open = false;
    root.dispatchEvent(new Event('toggle'));
    root.open = true;
    root.dispatchEvent(new Event('toggle'));
    await Promise.resolve();

    expect(client.feature).toHaveBeenCalledTimes(1);
    expect(form.elements.namedItem('quote').value).toBe('The quick brown fox.');
    expect(root.querySelector('[data-correction-quote]').hidden).toBe(false);
    expect(root.querySelector('[data-correction-quote]').textContent).toBe('The quick brown fox.');
  });

  it('submits through the form event and wires every block on the page', async () => {
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { corrections: true } };
    const controllers = initCorrectionReports(document);

    expect(controllers).toHaveLength(1);
    expect(controllers[0].available).toBe(true);
    const spy = vi.spyOn(controllers[0], 'submit').mockResolvedValue(null);
    form.dispatchEvent(new Event('submit', { cancelable: true }));
    expect(spy).toHaveBeenCalled();
    delete window.DatalogDynamicServices;
  });
});

describe('patch correction quote regressions', () => {
  it('captures before pointer selection collapses and clears the hidden quote on success', async () => {
    const root = mount();
    const client = fakeClient();
    const controller = initCorrectionReport(root, { client });
    const form = root.querySelector('form');
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(document.querySelector('.post-content p'));
    selection.removeAllRanges();
    selection.addRange(range);
    root.querySelector('summary').dispatchEvent(new Event('pointerdown'));
    selection.removeAllRanges();
    root.open = true;
    root.dispatchEvent(new Event('toggle'));
    expect(form.elements.quote.value).toBe('The quick brown fox.');
    fill(form, { message: 'A sufficiently detailed correction report.' });
    await controller.submit();
    expect(form.elements.quote.value).toBe('');
    fill(form, { message: 'Another sufficiently detailed report.' });
    await controller.submit();
    expect(client.post.mock.calls[1][1]).not.toHaveProperty('quote');
  });
});
