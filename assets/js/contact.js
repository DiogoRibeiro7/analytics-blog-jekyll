/**
 * @fileoverview Entry for the contact and collaboration form (#261). Loaded
 * by assets/js/loader.js when a page carries [data-contact-form].
 */

import { initContactForms } from "./contact/form.js";

function start() {
  initContactForms(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
