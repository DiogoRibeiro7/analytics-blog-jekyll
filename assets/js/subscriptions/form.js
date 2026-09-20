/**
 * @fileoverview The newsletter subscribe form (#254): an email address and,
 * when the site offers them, topics, sent to the site's dynamic services
 * (docs/dynamic-services.md). With double opt-in the answer is "pending":
 * nothing is sent to the address until its owner confirms from the email.
 * The address never reaches a page, a feed or an analytics product.
 * @module subscriptions/form
 */

import { getClient } from "../dynamic-services/client.js";
import { createAvailabilityCheck, createSubmission, readForm, setFormState, showFailure } from "../dynamic-services/form-state.js";

export const FEATURE = "subscriptions";
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function jsonIn(root, selector) {
  const holder = root.querySelector(selector);
  if (!holder) {
    return {};
  }
  try {
    return JSON.parse(holder.textContent) || {};
  } catch (error) {
    return {};
  }
}


/**
 * What the form sends: the address, the topics ticked (always a list, left
 * out when the site has none), the page and the reader's language. The
 * honeypot is left out.
 * @param {Object} fields - readForm's result
 * @param {Object} context - `sourceUrl`, `locale`, `hasTopics`
 * @returns {Object}
 */
export function buildSubscription(fields, context = {}) {
  const subscription = { email: fields.email || "" };
  if (context.hasTopics) {
    subscription.topics = [].concat(fields.topics || []).filter(Boolean);
  }
  if (context.sourceUrl) {
    subscription.source_url = context.sourceUrl;
  }
  if (context.locale) {
    subscription.locale = context.locale;
  }
  return subscription;
}

/**
 * Checks before a request: an address that looks like one, a topic when the
 * site offers topics, and an empty honeypot.
 * @param {Object} subscription
 * @param {Object} fields - The raw fields, for the honeypot
 * @param {Object} labels
 * @returns {Object|null} Field errors, or null when the subscription can go
 */
export function validate(subscription, fields, labels = {}) {
  const errors = {};
  if (!EMAIL.test(subscription.email)) {
    errors.email = labels.email_invalid || "That does not look like an email address.";
  }
  if (Array.isArray(subscription.topics) && subscription.topics.length === 0) {
    errors.topics = labels.topics_required || "Pick at least one.";
  }
  if (fields.website) {
    errors.website = "spam";
  }
  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * Wires one subscribe form.
 * @param {Element} root - The element carrying data-subscribe
 * @param {Object} [deps] - `client`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initSubscribeForm(root, deps = {}) {
  const client = deps.client || getClient();
  const form = root.querySelector("form");
  const labels = jsonIn(root, "[data-subscribe-labels]");
  const errorLabels = labels.errors || {};
  // The footer form is rendered once for every page, so it says nothing of the
  // page: the canonical link and <html lang> do.
  const doc = root.ownerDocument;
  const canonical = doc.querySelector('link[rel="canonical"]');
  const context = {
    sourceUrl: root.dataset.subscribeSource || (canonical && canonical.href) || "",
    locale: root.dataset.subscribeLocale || doc.documentElement.lang || "",
    hasTopics: form.querySelector('[name="topics"]') !== null
  };
  const doubleOptIn = root.dataset.subscribeDoubleOptIn !== "false";
  const submission = createSubmission(form);

  const finish = (result) => {
    form.dataset.result = result;
    setFormState(form, "success", labels[result] || "");
  };

  if (!client.enabled) {
    setFormState(form, "disabled", errorLabels.disabled || "");
    return { form, available: false, submit: async () => null };
  }

  /** Asks the service once whether it takes subscriptions; a refusal disables the form. */
  const ensureAvailable = createAvailabilityCheck(client, FEATURE, form, errorLabels);

  // The first time the reader reaches into the form, not on page load.
  form.addEventListener("focusin", () => ensureAvailable().catch(() => {}), { once: true });

  const controller = {
    form,
    available: true,
    /**
     * Sends the subscription. Resolves the service's answer, or null when
     * nothing was sent or the service refused.
     */
    async submit() {
      const fields = readForm(form);
      const subscription = buildSubscription(fields, context);
      const errors = validate(subscription, fields, labels);
      delete form.dataset.result;
      if (errors) {
        if (errors.website) {
          // A filled honeypot is a bot: pretend it is pending and send nothing.
          finish("pending");
          return null;
        }
        setFormState(form, "invalid", errorLabels.invalid || "", errors);
        return null;
      }
      setFormState(form, "pending", labels.sending || "");
      try {
        await ensureAvailable();
      } catch (error) {
        return null;
      }
      try {
        const answer = await client.post(client.pathFor(FEATURE), subscription, { idempotencyKey: submission.key(subscription) });
        const status = answer && answer.data && typeof answer.data.status === "string" ? answer.data.status : "";
        submission.clear();
        form.reset();
        // The service says which; when it does not, the site's setting does.
        finish(status === "confirmed" || status === "subscribed" || (status === "" && !doubleOptIn) ? "confirmed" : "pending");
        return answer;
      } catch (error) {
        if (error && error.kind === "conflict") {
          // Already on the list: not a failure, and nothing more to do.
          finish("duplicate");
        } else {
          showFailure(form, error, errorLabels);
        }
        return null;
      }
    }
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    controller.submit();
  });

  return controller;
}

/**
 * Wires every subscribe form on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initSubscribeForms(doc = document) {
  return Array.from(doc.querySelectorAll("[data-subscribe]")).map((root) => initSubscribeForm(root));
}
