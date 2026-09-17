/**
 * @fileoverview Article reactions (#255): "Was this useful?" with a small,
 * configurable set of answers, read from and sent to the site's dynamic
 * services (docs/dynamic-services.md). The counts shown are the service's
 * own, never made up: without an answer they stay hidden. The only thing
 * kept in the browser is the reader's own choice, so their device shows it
 * again; nothing identifies the reader to the service.
 * @module reactions/widget
 */

import { describeError, getClient } from "../dynamic-services/client.js";

export const FEATURE = "reactions";
export const STORAGE_PREFIX = "datalog-reaction:";
const OFF = new Set(["disabled", "unsupported", "version"]);

function jsonIn(root, selector) {
  const holder = root.querySelector(selector);
  if (!holder) {
    return {};
  }
  try {
    return JSON.parse(holder.textContent) || {};
  } catch (error) {
    return {};
  }
}

function newKey() {
  const crypto = globalThis.crypto;
  return crypto && typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

/** The reader's own choice for a page, on this device; null when none or when storage is unavailable. */
export function storedChoice(storage, path) {
  try {
    return storage ? storage.getItem(STORAGE_PREFIX + path) : null;
  } catch (error) {
    return null;
  }
}

export function storeChoice(storage, path, reaction) {
  try {
    if (storage) {
      storage.setItem(STORAGE_PREFIX + path, reaction);
    }
  } catch (error) {
    // A full or blocked storage only means the choice is not shown again.
  }
}

/**
 * The counts in a service answer, when it has the shape of the contract:
 * an object of reaction to non-negative integer. Anything else is treated as
 * no counts at all, so nothing invented reaches the page.
 * @param {*} data
 * @returns {Object.<string, number>|null}
 */
export function countsIn(data) {
  const counts = data && typeof data === "object" ? data.counts : null;
  if (!counts || typeof counts !== "object" || Array.isArray(counts)) {
    return null;
  }
  const clean = {};
  Object.keys(counts).forEach((key) => {
    const value = counts[key];
    if (Number.isInteger(value) && value >= 0) {
      clean[key] = value;
    }
  });
  return clean;
}

/**
 * Wires one reactions strip.
 * @param {Element} root - The element carrying data-reactions
 * @param {Object} [deps] - `client`, `storage`, `window` and `immediate`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initReactions(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = deps.window || doc.defaultView;
  const client = deps.client || getClient();
  const storage = deps.storage === undefined ? safeStorage(win) : deps.storage;
  const path = root.dataset.reactionsPath || "/";
  const showCounts = root.dataset.reactionsCounts !== "false";
  const labels = jsonIn(root, "[data-reactions-labels]");
  const errorLabels = labels.errors || {};
  const status = root.querySelector("[data-reactions-status]");
  const buttons = Array.from(root.querySelectorAll("[data-reaction]"));
  let availability = null;
  let loaded = false;
  let sending = false;
  let selected = storedChoice(storage, path);

  const setStatus = (message, alert = false) => {
    if (!status) {
      return;
    }
    status.textContent = message;
    status.hidden = message === "";
    status.setAttribute("role", alert ? "alert" : "status");
  };

  const setState = (state) => {
    root.dataset.state = state;
  };

  const showSelection = () => {
    buttons.forEach((button) => {
      button.setAttribute("aria-pressed", button.dataset.reaction === selected ? "true" : "false");
    });
  };

  const showCountsOf = (counts) => {
    buttons.forEach((button) => {
      const slot = button.querySelector("[data-reaction-count]");
      if (!slot) {
        return;
      }
      const value = showCounts && counts ? counts[button.dataset.reaction] : undefined;
      if (Number.isInteger(value)) {
        slot.textContent = String(value);
        slot.hidden = false;
      } else {
        slot.textContent = "";
        slot.hidden = true;
      }
    });
  };

  const setBusy = (busy) => {
    root.setAttribute("aria-busy", busy ? "true" : "false");
    buttons.forEach((button) => {
      button.disabled = busy;
    });
  };

  const disable = (error) => {
    setState("disabled");
    showCountsOf(null);
    buttons.forEach((button) => {
      button.disabled = true;
    });
    setStatus(describeError(error, errorLabels));
  };

  const ensureAvailable = () => {
    if (!availability) {
      availability = client.feature(FEATURE).catch((error) => {
        availability = null;
        throw error;
      });
    }
    return availability;
  };

  const controller = {
    root,
    get selected() {
      return selected;
    },

    /** Fetches the counts. Resolves them, or null when the service gave none. */
    async load() {
      setState("loading");
      try {
        await ensureAvailable();
        const answer = await client.get(`${client.pathFor(FEATURE)}?path=${encodeURIComponent(path)}`);
        const counts = countsIn(answer && answer.data);
        showCountsOf(counts);
        setState("loaded");
        loaded = true;
        return counts;
      } catch (error) {
        if (error && OFF.has(error.kind)) {
          disable(error);
        } else {
          // The service could not be read: no counts, but a reaction may still be sent.
          showCountsOf(null);
          setState("unavailable");
        }
        return null;
      }
    },

    /**
     * Sends a reaction. Resolves the service's answer, or null when nothing
     * was sent: the same choice again, a send in progress, or the feature off.
     */
    async react(reaction) {
      if (sending || !buttons.some((button) => button.dataset.reaction === reaction)) {
        return null;
      }
      if (reaction === selected) {
        setStatus(labels.already || "");
        return null;
      }
      sending = true;
      setBusy(true);
      setState("pending");
      setStatus(labels.sending || "");
      try {
        await ensureAvailable();
        const answer = await client.post(client.pathFor(FEATURE), { path, reaction }, { idempotencyKey: newKey() });
        selected = reaction;
        storeChoice(storage, path, reaction);
        showSelection();
        const counts = countsIn(answer && answer.data);
        if (counts) {
          showCountsOf(counts);
        }
        setState("selected");
        setStatus(labels.thanks || "");
        return answer;
      } catch (error) {
        if (error && OFF.has(error.kind)) {
          disable(error);
        } else if (error && error.kind === "conflict") {
          // The service already has this reader's reaction: keep what it says.
          selected = reaction;
          storeChoice(storage, path, reaction);
          showSelection();
          setState("selected");
          setStatus(labels.already || "");
        } else {
          setState(loaded ? "loaded" : "unavailable");
          setStatus(describeError(error, errorLabels), true);
        }
        return null;
      } finally {
        sending = false;
        if (root.dataset.state !== "disabled") {
          setBusy(false);
        }
      }
    }
  };

  showSelection();
  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      controller.react(button.dataset.reaction);
    });
  });

  // The counts are fetched when the reader gets near the strip, not with the article.
  const start = () => {
    if (!loaded) {
      controller.load();
    }
  };
  if (deps.immediate || !win || typeof win.IntersectionObserver !== "function") {
    start();
  } else {
    const observer = new win.IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          observer.disconnect();
          start();
        }
      },
      { rootMargin: "400px 0px" }
    );
    observer.observe(root);
  }

  return controller;
}

function safeStorage(win) {
  try {
    return win && win.localStorage ? win.localStorage : null;
  } catch (error) {
    return null;
  }
}

/**
 * Wires every reactions strip on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initAllReactions(doc = document) {
  return Array.from(doc.querySelectorAll("[data-reactions]")).map((root) => initReactions(root));
}
