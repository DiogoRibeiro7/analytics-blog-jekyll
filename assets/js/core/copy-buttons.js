/**
 * @fileoverview Copy buttons: the citation and bibliography exports, and the
 * installation commands on a package page. Those render on every post,
 * dataset, project and package, so they are handled here in the core bundle,
 * with one delegated listener, rather than by the academic bundle, which
 * those pages never load.
 * @module core/copy-buttons
 */

/** @constant {string} Buttons that copy the text of the element named by data-target */
const TRIGGER_SELECTOR = "[data-copy-citation], [data-copy-bibliography], [data-copy-target]";
/** @constant {number} How long the confirmation stays on the button, in ms */
const FEEDBACK_MS = 2000;

let listening = false;

function textToCopy(trigger) {
  const targetId = trigger.getAttribute("data-target");
  const target = targetId ? document.getElementById(targetId) : null;
  if (!target) {
    return "";
  }
  return "value" in target ? target.value : target.textContent || "";
}

/**
 * The clipboard API needs a secure context and a permission; where it is
 * missing or refused, the selection-and-execCommand route still works. It is
 * deprecated and still the only fallback browsers offer.
 * @param {string} text
 * @returns {boolean} Whether the text was copied
 */
function copyByExecCommand(text) {
  const field = document.createElement("textarea");
  field.value = text;
  field.setAttribute("aria-hidden", "true");
  field.setAttribute("readonly", "readonly");
  field.style.position = "fixed";
  field.style.opacity = "0";
  document.body.appendChild(field);
  field.select();
  let copied = false;
  try {
    copied = document.execCommand("copy");
  } catch (error) {
    copied = false;
  }
  field.remove();
  return copied;
}

async function writeToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (error) {
      // Refused or unavailable: the older route may still work.
    }
  }
  return copyByExecCommand(text);
}

async function copy(trigger) {
  const text = textToCopy(trigger);
  if (!text) {
    return;
  }
  if (trigger.dataset.originalText === undefined) {
    trigger.dataset.originalText = trigger.textContent;
  }

  const copied = await writeToClipboard(text);
  // A template passes the words, so a site that is not in English gets its own.
  trigger.dataset.copied = copied ? "true" : "error";
  trigger.textContent = copied
    ? trigger.dataset.copiedLabel || "Copied!"
    : trigger.dataset.errorLabel || "Error";
  if (!copied) {
    return;
  }
  setTimeout(() => {
    trigger.dataset.copied = "false";
    trigger.textContent = trigger.dataset.originalText;
  }, FEEDBACK_MS);
}

/**
 * Handles clicks on copy buttons anywhere in the document, including buttons
 * added later. Calling it again does not add a second listener.
 * @returns {void}
 */
export function initCopyButtons() {
  if (listening) {
    return;
  }
  listening = true;
  document.addEventListener("click", (event) => {
    const trigger = event.target instanceof Element ? event.target.closest(TRIGGER_SELECTOR) : null;
    if (trigger) {
      copy(trigger);
    }
  });
}
