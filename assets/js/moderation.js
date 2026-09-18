/**
 * @fileoverview Entry for the moderation inbox (#257). Loaded by
 * assets/js/loader.js when a page carries [data-moderation-inbox].
 */

import { initModerationInboxes } from "./moderation/inbox.js";

function start() {
  initModerationInboxes(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
