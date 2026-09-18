/**
 * @fileoverview Entry for article reactions (#255). Loaded by
 * assets/js/loader.js when a page carries [data-reactions].
 */

import { initAllReactions } from "./reactions/widget.js";

function start() {
  initAllReactions(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
