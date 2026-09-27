/**
 * @fileoverview Dark mode toggle functionality.
 * Persists the visitor's choice and uses the site's color scheme default.
 * @module core/dark-mode
 */

/** @constant {string} LocalStorage key for color mode preference */
const STORAGE_KEY = "datalog-color-mode";
/** @constant {string} Class applied to body for dark mode */
const DARK_CLASS = "dark-mode";
/** @constant {string} The query the image pipeline writes on a dark figure's sources */
const DARK_MEDIA = "(prefers-color-scheme: dark)";
/** @constant {string} Every dark <source> the image pipeline emitted */
const DARK_SOURCES = "picture > source[data-dark-source]";

/**
 * Points every figure with a dark companion at the right file.
 *
 * `_plugins/image_optimizer.rb` writes those companions as
 * `<source media="(prefers-color-scheme: dark)">`, which follows the operating
 * system. This toggle does not: a reader whose system is light can switch the
 * site to dark, and would otherwise keep the white plot on the dark page. So
 * the effective page palette overrules the query — "all" for dark, "not all"
 * for light. Passing null explicitly restores the system query.
 *
 * With no JavaScript the figures still follow the system.
 * @param {"dark"|"light"|null} preference - Effective theme or null for the system query
 * @param {ParentNode} [root] - Where to look; the document by default
 * @returns {void}
 */
export function syncDarkFigures(preference, root = document) {
  let media = DARK_MEDIA;
  if (preference === "dark") {
    media = "all";
  } else if (preference === "light") {
    media = "not all";
  }
  root.querySelectorAll(DARK_SOURCES).forEach((source) => {
    if (source.getAttribute("media") !== media) {
      source.setAttribute("media", media);
    }
  });
}

/**
 * Reads the saved preference. Storage access throws where the browser blocks
 * it (Safari with all cookies blocked, sandboxed iframes, some privacy
 * extensions), and that exception used to stop the whole core bundle, so it
 * counts as no saved preference.
 * @returns {string|null} "dark", "light" or null
 */
function readStoredPreference() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch (error) {
    return null;
  }
}

/**
 * Saves the preference where storage is available. Where it is blocked the
 * choice still applies to the page but is not remembered.
 * @param {string} value - "dark" or "light"
 * @returns {void}
 */
function storePreference(value) {
  try {
    localStorage.setItem(STORAGE_KEY, value);
  } catch (error) {
    // Storage is blocked: there is nowhere to remember the choice.
  }
}

/**
 * Resolves the initial mode from storage, the site default, or the system.
 * The inline script at the top of <body> in _layouts/default.html applies the
 * same rule before the first paint, so the two have to stay in step.
 * @param {MediaQueryList} prefersDarkScheme - Media query for dark scheme preference
 * @param {"dark"|"light"|"system"} siteDefault - Site's configured initial mode
 * @returns {boolean} True if dark mode should be enabled
 */
function resolveInitialPreference(prefersDarkScheme, siteDefault) {
  const storedPreference = readStoredPreference();
  if (storedPreference === "dark") {
    return true;
  }
  if (storedPreference === "light") {
    return false;
  }
  return siteDefault === "dark" || (siteDefault === "system" && prefersDarkScheme.matches);
}

/**
 * Initializes the dark mode toggle button and system preference listener.
 * Reads the saved preference before falling back to the site's initial mode.
 * @returns {void}
 */
export function initDarkModeToggle() {
  const toggleButton = document.querySelector("[data-toggle-dark-mode]");
  const body = document.body;
  const prefersDarkScheme = window.matchMedia("(prefers-color-scheme: dark)");
  const configuredDefault = body.dataset.defaultTheme;
  /** @type {"dark"|"light"|"system"} */
  const siteDefault = ["dark", "light", "system"].includes(configuredDefault)
    ? configuredDefault
    : "dark";

  const isDark = resolveInitialPreference(prefersDarkScheme, siteDefault);
  body.classList.toggle(DARK_CLASS, isDark);
  syncDarkFigures(isDark ? "dark" : "light");

  /** Mirrors the effective theme on <body data-theme> for CSS hooks and tests. */
  const syncThemeAttribute = () => {
    const theme = body.classList.contains(DARK_CLASS) ? "dark" : "light";
    body.dataset.theme = theme;
    document.documentElement.dataset.theme = theme;
  };

  const syncButton = () => {
    syncThemeAttribute();
    if (!toggleButton) {
      return;
    }
    toggleButton.setAttribute("aria-pressed", body.classList.contains(DARK_CLASS));
  };

  syncButton();

  if (toggleButton) {
    toggleButton.addEventListener("click", () => {
      const isDark = body.classList.toggle(DARK_CLASS);
      toggleButton.setAttribute("aria-pressed", String(isDark));
      storePreference(isDark ? "dark" : "light");
      syncThemeAttribute();
      syncDarkFigures(isDark ? "dark" : "light");
    });
  }

  prefersDarkScheme.addEventListener("change", (event) => {
    if (readStoredPreference() || siteDefault !== "system") {
      return;
    }
    if (event.matches) {
      body.classList.add(DARK_CLASS);
    } else {
      body.classList.remove(DARK_CLASS);
    }
    syncDarkFigures(event.matches ? "dark" : "light");
    syncButton();
  });
}
