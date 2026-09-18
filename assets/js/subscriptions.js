/**
 * @fileoverview Entry for newsletter subscriptions (#254): the subscribe
 * forms and the page the emails link to. Loaded by assets/js/loader.js when
 * a page carries [data-subscribe] or [data-subscription-manage].
 */

import { initSubscribeForms } from "./subscriptions/form.js";
import { initSubscriptionManagers } from "./subscriptions/manage.js";

function start() {
  initSubscribeForms(document);
  initSubscriptionManagers(document);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
