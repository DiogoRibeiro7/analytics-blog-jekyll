/**
 * @fileoverview Entry point of the corrections bundle (#256): the
 * correction-report form on posts, sent through the dynamic-services client.
 * The loader imports it on a page that carries data-correction-report.
 * @module corrections
 */

import { initCorrectionReports } from "./corrections/form.js";

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => initCorrectionReports());
} else {
  initCorrectionReports();
}

export { initCorrectionReports };
