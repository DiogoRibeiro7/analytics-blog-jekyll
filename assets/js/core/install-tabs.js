/**
 * @fileoverview The installation panel's tabs — pip, conda, Git for a Python
 * package, CRAN and GitHub for an R one.
 *
 * They were three buttons toggling `hidden`, with no tab semantics and no
 * keyboard beyond Tab: a screen reader heard three unlabelled buttons and
 * nothing about which one was showing. Here they are a real tablist, so the
 * arrow keys move between them, Home and End reach the ends, and the selected
 * one is announced (#332).
 * @module core/install-tabs
 */

const KEYS = {
  ArrowRight: 1,
  ArrowDown: 1,
  ArrowLeft: -1,
  ArrowUp: -1
};

/**
 * Shows one panel of a tablist and marks its tab as the selected one.
 * @param {Element[]} tabs
 * @param {Element[]} panels
 * @param {Element} chosen - The tab to select
 * @param {boolean} [focus] - Whether to move focus to it, as the arrow keys do
 * @returns {void}
 */
export function selectTab(tabs, panels, chosen, focus = false) {
  tabs.forEach((tab) => {
    const selected = tab === chosen;
    tab.setAttribute("aria-selected", selected ? "true" : "false");
    // Only the selected tab is a tab stop: the arrow keys move within the set.
    tab.tabIndex = selected ? 0 : -1;
    tab.classList.toggle("package-install__tab-btn--active", selected);
  });
  panels.forEach((panel) => {
    panel.hidden = panel.dataset.tabContent !== chosen.dataset.tab;
  });
  if (focus) {
    chosen.focus();
  }
}

/**
 * Wires one installation panel.
 * @param {Element} container - The element carrying data-install-tabs
 * @returns {Object|null} The controller, for tests
 */
export function initInstallTabs(container) {
  const tabs = Array.from(container.querySelectorAll("[data-tab]"));
  const panels = Array.from(container.querySelectorAll("[data-tab-content]"));
  if (tabs.length === 0) {
    return null;
  }

  const selected = tabs.find((tab) => tab.getAttribute("aria-selected") === "true") || tabs[0];
  selectTab(tabs, panels, selected);

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => selectTab(tabs, panels, tab));
    tab.addEventListener("keydown", (event) => {
      if (event.key === "Home" || event.key === "End") {
        event.preventDefault();
        selectTab(tabs, panels, event.key === "Home" ? tabs[0] : tabs[tabs.length - 1], true);
        return;
      }
      const step = KEYS[event.key];
      if (!step) {
        return;
      }
      event.preventDefault();
      const next = (tabs.indexOf(tab) + step + tabs.length) % tabs.length;
      selectTab(tabs, panels, tabs[next], true);
    });
  });

  return { container, tabs, panels };
}

/**
 * Wires every installation panel on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initAllInstallTabs(doc = document) {
  return Array.from(doc.querySelectorAll("[data-install-tabs]"))
    .map((container) => initInstallTabs(container))
    .filter(Boolean);
}
