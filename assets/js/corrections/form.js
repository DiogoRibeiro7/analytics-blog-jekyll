/**
 * @fileoverview The correction-report form (#256): a reader reports a
 * mathematical or factual error, a broken citation, outdated code, a
 * reproducibility failure, a typo or an accessibility problem, as structured
 * feedback apart from comments. The report goes to the site's dynamic
 * services (docs/dynamic-services.md) and is never shown on the page: it is
 * an incoming claim, and the revision history is what the author publishes
 * after review.
 * @module corrections/form
 */

import { getClient } from "../dynamic-services/client.js";
import { readForm, setFormState, showFailure } from "../dynamic-services/form-state.js";

export const FEATURE = "corrections";
export const MIN_MESSAGE = 20;
export const MAX_QUOTE = 500;

function labelsOf(root) {
  const holder = root.querySelector("[data-correction-labels]");
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
 * Fills the section list from the article's headings, so a report can say
 * where the problem is.
 * @param {HTMLSelectElement|null} select
 * @param {Element|null} content
 */
export function fillSections(select, content) {
  if (!select || !content) {
    return;
  }
  content.querySelectorAll("h2[id], h3[id]").forEach((heading) => {
    const option = select.ownerDocument.createElement("option");
    option.value = heading.id;
    option.textContent = heading.textContent.trim();
    select.appendChild(option);
  });
}

/**
 * The text the reader had selected when they opened the form, when it is in the article.
 * @param {Window} win
 * @param {Element|null} content
 * @returns {string}
 */
export function selectedQuote(win, content) {
  const selection = win.getSelection && win.getSelection();
  if (!selection || selection.isCollapsed || selection.rangeCount === 0 || !content) {
    return "";
  }
  const range = selection.getRangeAt(0);
  return content.contains(range.commonAncestorContainer) ? selection.toString().trim().slice(0, MAX_QUOTE) : "";
}

/**
 * What the form sends: the reader's fields, the article's address and
 * title, and the quote when there was one. The honeypot is left out.
 * @param {Object} fields - readForm's result
 * @param {Object} article - `url` and `title`
 * @returns {Object}
 */
export function buildReport(fields, article) {
  const report = {
    category: fields.category || "other",
    message: fields.message || "",
    article: { url: article.url, title: article.title }
  };
  if (fields.section) {
    report.section = fields.section;
  }
  if (fields.contact_email) {
    report.contact_email = fields.contact_email;
  }
  if (fields.quote) {
    report.quote = fields.quote;
  }
  return report;
}

/**
 * Checks before a request: a message long enough, a valid email when one is
 * given, and an empty honeypot.
 * @param {Object} report
 * @param {Object} fields - The raw fields, for the honeypot
 * @param {Object} labels
 * @returns {Object|null} Field errors, or null when the report can go
 */
export function validate(report, fields, labels = {}) {
  const errors = {};
  if (report.message.length < MIN_MESSAGE) {
    errors.message = (labels.message_short || "Say a little more: at least {{min}} characters.")
      .split("{{min}}")
      .join(String(MIN_MESSAGE));
  }
  if (report.contact_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(report.contact_email)) {
    errors.contact_email = labels.email_invalid || "That does not look like an email address.";
  }
  if (fields.website) {
    errors.website = "spam";
  }
  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * Wires one correction-report block.
 * @param {Element} root - The <details> carrying data-correction-report
 * @param {Object} [deps] - `client`, `content` and `window`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initCorrectionReport(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = deps.window || doc.defaultView;
  const client = deps.client || getClient();
  const content = deps.content === undefined ? doc.querySelector(".post-content") : deps.content;
  const form = root.querySelector("form");
  const labels = labelsOf(root);
  const errorLabels = labels.errors || {};
  const article = { url: root.dataset.articleUrl || "", title: root.dataset.articleTitle || "" };
  const quoteField = form.elements.namedItem("quote");
  const quoteShown = root.querySelector("[data-correction-quote]");
  let availability = null;

  fillSections(form.elements.namedItem("section"), content);

  if (!client.enabled) {
    setFormState(form, "disabled", errorLabels.disabled || "");
    return { form, available: false, submit: async () => null };
  }

  /** Asks the service once whether it takes reports; a refusal disables the form. */
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

  const details = root.tagName === "DETAILS" ? root : root.querySelector("details");
  if (details) {
    details.addEventListener("toggle", () => {
      if (!details.open) {
        return;
      }
      const text = selectedQuote(win, content);
      if (quoteField && text && !quoteField.value) {
        quoteField.value = text;
        if (quoteShown) {
          quoteShown.textContent = text;
          quoteShown.hidden = false;
        }
      }
      ensureAvailable().catch(() => {});
    });
  }

  const controller = {
    form,
    available: true,
    /**
     * Sends the report. Resolves the service's answer, or null when nothing
     * was sent: the fields failed a check, or the service does not take reports.
     */
    async submit() {
      const fields = readForm(form);
      const report = buildReport(fields, article);
      const errors = validate(report, fields, labels);
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
        const answer = await client.post(client.pathFor(FEATURE), report, { idempotencyKey: newKey() });
        form.reset();
        if (quoteShown) {
          quoteShown.hidden = true;
        }
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
 * Wires every correction-report block on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initCorrectionReports(doc = document) {
  return Array.from(doc.querySelectorAll("[data-correction-report]")).map((root) => initCorrectionReport(root));
}
