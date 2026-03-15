/**
 * @fileoverview Language filter dropdown handler.
 * @module core/language-filter
 */

/**
 * Initializes language filter dropdown to navigate on selection.
 * @returns {void}
 */
export function initLanguageFilter() {
  const languageFilter = document.querySelector("[data-language-filter]");
  if (!languageFilter) {
    return;
  }

  languageFilter.addEventListener("change", (event) => {
    const target = event.target;
    if (target && target.value) {
      window.location.href = target.value;
    }
  });
}
