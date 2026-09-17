/**
 * @fileoverview Entry point of the reading-state bundle (#260): bookmarks,
 * reading progress and private highlights, kept in the browser. The loader
 * imports it on a page that carries data-reading-state or data-reading-list.
 * @module reading-state
 */

import { initReadingState } from "./reading-state/ui.js";

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => initReadingState());
} else {
  initReadingState();
}

export { initReadingState };
