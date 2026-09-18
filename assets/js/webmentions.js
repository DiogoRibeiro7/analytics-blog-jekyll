/**
 * @fileoverview Entry for "Mentioned elsewhere" (#258). Loaded by
 * assets/js/loader.js when a page carries [data-webmentions].
 */

import { initAllWebmentions } from "./webmentions/list.js";

function start() {
  initAllWebmentions(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
