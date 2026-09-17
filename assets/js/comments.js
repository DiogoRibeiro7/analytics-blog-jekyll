/**
 * @fileoverview Entry for the comments thread of the `api` provider (#253).
 * Loaded by assets/js/loader.js when a page carries [data-comments-thread].
 */

import { initCommentsThreads } from "./comments/thread.js";

function start() {
  initCommentsThreads(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
