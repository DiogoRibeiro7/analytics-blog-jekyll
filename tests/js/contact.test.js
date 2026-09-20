import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '../../assets/js/dynamic-services/client.js';
import {
  MIN_MESSAGE,
  buildMessage,
  initContactForm,
  initContactForms,
  validate,
} from '../../assets/js/contact/form.js';

/**
 * The contact and collaboration form (#261): what it sends, what it checks
 * before sending, the prompt that follows the category, and every state a
 * submission can end in.
 */

const LABELS = {
  pending: 'Sending…',
  success: 'Thank you.',
  name_required: 'Who are you?',
  email_invalid: 'Not an email.',
  subject_required: 'A subject, please.',
  message_short: 'At least {{min}} characters.',
  errors: { invalid: 'Check the fields.', network: 'Unreachable.', rate_limited: 'Wait.', unsupported: 'Not offered.', disabled: 'Off.', reference: 'Ref {{id}}' },
};

const PROMPTS = { 'research-collaboration': 'Which question, data or method?', media: 'Outlet, topic and deadline.' };

const MARKUP = `
<section data-contact-form data-source-url="https://example.org/contact/">
  <script type="application/json" data-contact-labels>${JSON.stringify(LABELS)}</script>
  <script type="application/json" data-contact-prompts>${JSON.stringify(PROMPTS)}</script>
  <form id="contact-form" novalidate>
    <fieldset>
      <select name="category">
        <option value="research-collaboration">Collaboration</option>
        <option value="consulting">Consulting</option>
        <option value="media">Media</option>
      </select>
      <input name="name"><p data-error-for="name" hidden></p>
      <input name="email"><p data-error-for="email" hidden></p>
      <input name="affiliation">
      <input name="subject"><p data-error-for="subject" hidden></p>
      <textarea name="message"></textarea>
      <p data-contact-hint>Default hint.</p>
      <p data-error-for="message" hidden></p>
      <input name="website">
    </fieldset>
    <button type="submit">Send</button>
    <p data-form-status hidden></p>
  </form>
</section>`;

const VALID = {
  category: 'consulting',
  name: 'Jane Doe',
  email: 'jane@example.org',
  affiliation: 'Example University',
  subject: 'Longitudinal models',
  message: 'We would like help with a longitudinal model of adherence.',
};

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
  return document.querySelector('[data-contact-form]');
}

function fill(form, values) {
  Object.entries(values).forEach(([name, value]) => {
    form.elements.namedItem(name).value = value;
  });
}

describe('the message', () => {
  it('is built from the fields and the page, without the honeypot', () => {
    expect(buildMessage({ ...VALID, website: 'spam' }, 'https://example.org/contact/')).toEqual({
      ...VALID,
      source_url: 'https://example.org/contact/',
    });
    expect(buildMessage({}, 'u')).toEqual({ category: 'other', name: '', email: '', subject: '', message: '', source_url: 'u' });
  });

  it('is checked for a name, an email, a subject, the message length and the honeypot', () => {
    const empty = buildMessage({ email: 'nope', message: 'short' }, 'u');

    expect(validate(empty, {}, LABELS)).toEqual({
      name: 'Who are you?',
      email: 'Not an email.',
      subject: 'A subject, please.',
      message: `At least ${MIN_MESSAGE} characters.`,
    });
    expect(validate(buildMessage(VALID, 'u'), {}, LABELS)).toBeNull();
    expect(validate(buildMessage(VALID, 'u'), { website: 'bot' }, LABELS)).toEqual({ website: 'spam' });
    expect(validate(empty, {}, {}).message).toContain('20');
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
    const controller = initContactForm(root, { client });
    fill(form, VALID);
    await controller.submit();
    expect(form.querySelector('button[type=submit]').disabled).toBe(false);
    await controller.submit();
    await controller.submit();
    expect(client.post.mock.calls).toHaveLength(2);
    expect(client.post.mock.calls[1][2].idempotencyKey).toBe(client.post.mock.calls[0][2].idempotencyKey);
    fill(form, VALID);
    await controller.submit();
    expect(client.post.mock.calls[2][2].idempotencyKey).not.toBe(client.post.mock.calls[0][2].idempotencyKey);
    client.post.mockRejectedValueOnce(new ServiceError('network', 'lost response'));
    fill(form, VALID);
    await controller.submit();
    form.elements.namedItem('subject').value += 'x';
    form.elements.namedItem('subject').dispatchEvent(new Event('input', { bubbles: true }));
    await controller.submit();
    expect(client.post.mock.calls[4][2].idempotencyKey).not.toBe(client.post.mock.calls[3][2].idempotencyKey);
  });

  it('sends a valid message with an idempotency key and shows success', async () => {
    const client = fakeClient();
    const controller = initContactForm(root, { client });
    fill(form, VALID);

    const answer = await controller.submit();

    expect(answer).toMatchObject({ requestId: 'req_1' });
    expect(client.feature).toHaveBeenCalledWith('contact');
    const [path, payload, options] = client.post.mock.calls[0];
    expect(path).toBe('/contact');
    expect(payload).toEqual({ ...VALID, source_url: 'https://example.org/contact/' });
    expect(options.idempotencyKey).toMatch(/\S+/);
    expect(form.dataset.state).toBe('success');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Thank you.');
    expect(form.elements.namedItem('message').value).toBe('');
  });

  it('leaves the affiliation out when it is empty', async () => {
    const client = fakeClient();
    const controller = initContactForm(root, { client });
    fill(form, { ...VALID, affiliation: '' });

    await controller.submit();

    expect(client.post.mock.calls[0][1]).not.toHaveProperty('affiliation');
  });

  it('shows the prompt for the category under the message', () => {
    initContactForm(root, { client: fakeClient() });
    const hint = root.querySelector('[data-contact-hint]');
    const category = form.elements.namedItem('category');

    expect(hint.textContent).toBe('Which question, data or method?');

    category.value = 'consulting';
    category.dispatchEvent(new Event('change'));
    expect(hint.textContent).toBe('Default hint.');

    category.value = 'media';
    category.dispatchEvent(new Event('change'));
    expect(hint.textContent).toBe('Outlet, topic and deadline.');
  });

  it('sends nothing for missing fields and marks them, the first focused', async () => {
    const client = fakeClient();
    const controller = initContactForm(root, { client });
    fill(form, { email: 'not-an-email', message: 'Too short.' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-error-for="name"]').textContent).toBe('Who are you?');
    expect(form.querySelector('[data-error-for="email"]').textContent).toBe('Not an email.');
    expect(form.querySelector('[data-error-for="subject"]').textContent).toBe('A subject, please.');
    expect(form.querySelector('[data-error-for="message"]').textContent).toBe(`At least ${MIN_MESSAGE} characters.`);
    expect(document.activeElement).toBe(form.elements.namedItem('name'));
  });

  it('pretends a bot succeeded and sends nothing', async () => {
    const client = fakeClient();
    const controller = initContactForm(root, { client });
    fill(form, { ...VALID, website: 'https://spam.example' });

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('success');
  });

  it('shows the service’s field errors, a rate limit and a network failure', async () => {
    const client = fakeClient();
    const controller = initContactForm(root, { client });
    fill(form, VALID);

    client.post.mockRejectedValueOnce(new ServiceError('invalid', 'x', { errors: { email: 'Use an institutional address.' } }));
    expect(await controller.submit()).toBeNull();
    expect(form.dataset.state).toBe('invalid');
    expect(form.querySelector('[data-error-for="email"]').textContent).toBe('Use an institutional address.');

    client.post.mockRejectedValueOnce(new ServiceError('rate_limited', 'x', { requestId: 'req_9', retryAfter: 60 }));
    await controller.submit();
    expect(form.dataset.state).toBe('error');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Wait. Try again in 60 seconds. Ref req_9');
    expect(form.querySelector('[data-form-status]').getAttribute('role')).toBe('alert');

    client.post.mockRejectedValueOnce(new ServiceError('network', 'x'));
    await controller.submit();
    expect(form.querySelector('[data-form-status]').textContent).toBe('Unreachable.');
    expect(form.querySelector('button').disabled).toBe(false);
    expect(form.elements.namedItem('message').value).toBe(VALID.message);
  });

  it('is disabled when the site has no backend or the service does not take messages', async () => {
    const off = initContactForm(root, { client: fakeClient({ enabled: false }) });

    expect(off.available).toBe(false);
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('button').disabled).toBe(true);
    expect(form.querySelector('[data-form-status]').textContent).toBe('Off.');

    root = mount();
    form = root.querySelector('form');
    const client = fakeClient({ feature: vi.fn().mockRejectedValue(new ServiceError('unsupported', 'x')) });
    const controller = initContactForm(root, { client });
    fill(form, VALID);

    expect(await controller.submit()).toBeNull();
    expect(client.post).not.toHaveBeenCalled();
    expect(form.dataset.state).toBe('disabled');
    expect(form.querySelector('[data-form-status]').textContent).toBe('Not offered.');
  });

  it('asks the service once, the first time the reader reaches into the form', async () => {
    const client = fakeClient();
    initContactForm(root, { client });

    form.elements.namedItem('name').dispatchEvent(new Event('focusin', { bubbles: true }));
    form.elements.namedItem('email').dispatchEvent(new Event('focusin', { bubbles: true }));
    await Promise.resolve();

    expect(client.feature).toHaveBeenCalledTimes(1);
  });

  it('submits through the form event and wires every form on the page', () => {
    window.DatalogDynamicServices = { base_url: 'https://api.example.test', features: { contact: true } };
    const controllers = initContactForms(document);

    expect(controllers).toHaveLength(1);
    expect(controllers[0].available).toBe(true);
    const spy = vi.spyOn(controllers[0], 'submit').mockResolvedValue(null);
    form.dispatchEvent(new Event('submit', { cancelable: true }));
    expect(spy).toHaveBeenCalled();
    delete window.DatalogDynamicServices;
  });
});
