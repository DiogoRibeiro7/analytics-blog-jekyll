/**
 * @fileoverview The contact and collaboration form (#261): a structured
 * message to the site's author, a research collaboration, a consulting
 * enquiry, an invitation to speak, a mentoring request, a reproducibility
 * question or a media request, sent to the site's dynamic services
 * (docs/dynamic-services.md). Nothing the sender writes reaches the page.
 * @module contact/form
 */

import { getClient } from "../dynamic-services/client.js";
import { readForm, setFormState, showFailure } from "../dynamic-services/form-state.js";

export const FEATURE = "contact";
export const MIN_MESSAGE = 20;

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

function newKey() {
  const crypto = globalThis.crypto;
  return crypto && typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

/**
 * What the form sends: the sender's fields and the page it was sent from.
 * The honeypot is left out; `affiliation` only when given.
 * @param {Object} fields - readForm's result
 * @param {string} sourceUrl
 * @returns {Object}
 */
export function buildMessage(fields, sourceUrl) {
  const message = {
    category: fields.category || "other",
    name: fields.name || "",
    email: fields.email || "",
    subject: fields.subject || "",
    message: fields.message || "",
    source_url: sourceUrl
  };
  if (fields.affiliation) {
    message.affiliation = fields.affiliation;
  }
  return message;
}

/**
 * Checks before a request: a name, an email that looks like one, a subject,
 * a message long enough, and an empty honeypot.
 * @param {Object} message
 * @param {Object} fields - The raw fields, for the honeypot
 * @param {Object} labels
 * @returns {Object|null} Field errors, or null when the message can go
 */
export function validate(message, fields, labels = {}) {
  const errors = {};
  if (!message.name) {
    errors.name = labels.name_required || "Say who you are.";
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(message.email)) {
    errors.email = labels.email_invalid || "That does not look like an email address.";
  }
  if (!message.subject) {
    errors.subject = labels.subject_required || "Give the message a subject.";
  }
  if (message.message.length < MIN_MESSAGE) {
    errors.message = (labels.message_short || "Say a little more: at least {{min}} characters.")
      .split("{{min}}")
      .join(String(MIN_MESSAGE));
  }
  if (fields.website) {
    errors.website = "spam";
  }
  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * Wires one contact form.
 * @param {Element} root - The element carrying data-contact-form
 * @param {Object} [deps] - `client`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initContactForm(root, deps = {}) {
  const client = deps.client || getClient();
  const form = root.querySelector("form");
  const labels = jsonIn(root, "[data-contact-labels]");
  const prompts = jsonIn(root, "[data-contact-prompts]");
  const errorLabels = labels.errors || {};
  const sourceUrl = root.dataset.sourceUrl || "";
  const category = form.elements.namedItem("category");
  const hint = root.querySelector("[data-contact-hint]");
  const defaultHint = hint ? hint.textContent : "";
  let availability = null;

  /** The hint under the message follows the category, when the category has a prompt. */
  const showPrompt = () => {
    if (hint) {
      hint.textContent = (category && prompts[category.value]) || defaultHint;
    }
  };
  if (category) {
    category.addEventListener("change", showPrompt);
    showPrompt();
  }

  if (!client.enabled) {
    setFormState(form, "disabled", errorLabels.disabled || "");
    return { form, available: false, submit: async () => null };
  }

  /** Asks the service once whether it takes messages; a refusal disables the form. */
  const ensureAvailable = () => {
    if (!availability) {
      availability = client.feature(FEATURE).catch((error) => {
        availability = null;
        showFailure(form, error, errorLabels);
        form.dataset.state = "disabled";
        form.querySelectorAll("button[type=submit]").forEach((button) => {
          button.disabled = true;
        });
        throw error;
      });
    }
    return availability;
  };

  // The first time the reader reaches into the form, not on page load.
  form.addEventListener("focusin", () => ensureAvailable().catch(() => {}), { once: true });

  const controller = {
    form,
    available: true,
    /**
     * Sends the message. Resolves the service's answer, or null when nothing
     * was sent: the fields failed a check, or the service does not take messages.
     */
    async submit() {
      const fields = readForm(form);
      const message = buildMessage(fields, sourceUrl);
      const errors = validate(message, fields, labels);
      if (errors) {
        if (errors.website) {
          // A filled honeypot is a bot: pretend it worked and send nothing.
          setFormState(form, "success", labels.success || "");
          return null;
        }
        setFormState(form, "invalid", errorLabels.invalid || "", errors);
        return null;
      }
      setFormState(form, "pending", labels.pending || "");
      try {
        await ensureAvailable();
      } catch (error) {
        return null;
      }
      try {
        const answer = await client.post(client.pathFor(FEATURE), message, { idempotencyKey: newKey() });
        form.reset();
        showPrompt();
        setFormState(form, "success", labels.success || "");
        return answer;
      } catch (error) {
        showFailure(form, error, errorLabels);
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
 * Wires every contact form on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initContactForms(doc = document) {
  return Array.from(doc.querySelectorAll("[data-contact-form]")).map((root) => initContactForm(root));
}
