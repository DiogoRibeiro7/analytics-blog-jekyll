/**
 * @fileoverview Form states for the forms that post to the dynamic services
 * (#256, #261): one way to show idle, pending, success, invalid, error and
 * disabled states accessibly. The form carries data-state and aria-busy;
 * [data-form-status] announces the message; the fields a 422 names get
 * aria-invalid and their [data-error-for] message, and the first is focused.
 * @module dynamic-services/form-state
 */

import { describeError } from "./client.js";

export const STATES = ["idle", "pending", "success", "invalid", "error", "disabled"];

function fieldsOf(form, name) {
  const found = form.elements.namedItem(name);
  if (!found) {
    return [];
  }
  return typeof found.setAttribute === "function" ? [found] : Array.from(found);
}

/**
 * Removes every field error the last submission left.
 * @param {HTMLFormElement} form
 */
export function clearFieldErrors(form) {
  form.querySelectorAll("[aria-invalid]").forEach((field) => {
    field.removeAttribute("aria-invalid");
    const described = (field.getAttribute("aria-describedby") || "")
      .split(/\s+/)
      .filter((id) => id && !id.endsWith("-error"))
      .join(" ");
    if (described) {
      field.setAttribute("aria-describedby", described);
    } else {
      field.removeAttribute("aria-describedby");
    }
  });
  form.querySelectorAll("[data-error-for]").forEach((slot) => {
    slot.textContent = "";
    slot.hidden = true;
  });
}

/**
 * Shows a 422's field errors next to their fields.
 * @param {HTMLFormElement} form
 * @param {Object.<string, string|string[]>} errors - Field name to message(s)
 * @returns {number} How many fields were marked
 */
export function applyFieldErrors(form, errors) {
  let marked = 0;
  let first = null;
  Object.keys(errors || {}).forEach((name) => {
    const message = Array.isArray(errors[name]) ? errors[name].join(" ") : String(errors[name]);
    const slot = form.querySelector(`[data-error-for="${name}"]`);
    if (slot) {
      slot.textContent = message;
      slot.hidden = false;
      if (!slot.id) {
        slot.id = `${form.id || "form"}-${name}-error`;
      }
    }
    fieldsOf(form, name).forEach((field) => {
      field.setAttribute("aria-invalid", "true");
      if (slot) {
        const described = (field.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean);
        if (!described.includes(slot.id)) {
          described.push(slot.id);
        }
        field.setAttribute("aria-describedby", described.join(" "));
      }
      first = first || field;
      marked += 1;
    });
  });
  if (first && typeof first.focus === "function") {
    first.focus();
  }
  return marked;
}

/**
 * Puts a form in a state and announces it.
 * @param {HTMLFormElement} form
 * @param {string} state - One of STATES
 * @param {string} [message]
 * @param {Object} [fieldErrors] - For `invalid`, the fields to mark
 */
export function setFormState(form, state, message = "", fieldErrors = null) {
  form.dataset.state = STATES.includes(state) ? state : "idle";
  const busy = state === "pending";
  form.setAttribute("aria-busy", busy ? "true" : "false");
  form.querySelectorAll("button[type=submit], [data-form-submit]").forEach((button) => {
    button.disabled = busy || state === "disabled";
  });
  form.querySelectorAll("fieldset").forEach((fieldset) => {
    fieldset.disabled = state === "disabled";
  });
  const status = form.querySelector("[data-form-status]");
  if (status) {
    status.setAttribute("role", state === "error" || state === "invalid" ? "alert" : "status");
    status.textContent = message;
    status.hidden = message === "";
  }
  clearFieldErrors(form);
  if (state === "invalid" && fieldErrors) {
    applyFieldErrors(form, fieldErrors);
  }
}

/**
 * The form's fields as an object of trimmed strings; a checkbox that is not
 * checked is left out, and a name that appears more than once is a list.
 * @param {HTMLFormElement} form
 * @returns {Object.<string, string|string[]>}
 */
export function readForm(form) {
  const values = {};
  new FormData(form).forEach((value, name) => {
    const text = typeof value === "string" ? value.trim() : value;
    if (name in values) {
      values[name] = [].concat(values[name], text);
    } else {
      values[name] = text;
    }
  });
  return values;
}

/**
 * Shows a failed submission: a 422 as `invalid` with its field errors, a 429
 * and the rest as `error`, with the message for the error's kind.
 * @param {HTMLFormElement} form
 * @param {Error} error
 * @param {Object.<string, string>} [labels] - Messages by kind, as describeError takes them
 */
export function showFailure(form, error, labels = {}) {
  const message = describeError(error, labels);
  if (error && error.kind === "invalid") {
    setFormState(form, "invalid", message, error.errors || null);
  } else {
    setFormState(form, "error", message);
  }
}
