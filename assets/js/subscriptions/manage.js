/**
 * @fileoverview The page the newsletter's emails link to (#254): it
 * confirms a subscription (`?confirm=<token>`), ends one
 * (`?unsubscribe=<token>`, after the reader presses the button) and changes
 * its topics (`?manage=<token>`), through the site's dynamic services. The
 * token stands for the subscriber; no account, and the address is never
 * shown. It is taken out of the address bar as soon as it is read, so it
 * does not travel in a referrer or stay in the history.
 * @module subscriptions/manage
 */

import { describeError, getClient } from "../dynamic-services/client.js";
import { FEATURE } from "./form.js";

export const ACTIONS = ["confirm", "unsubscribe", "manage"];
const TOKEN = /^[A-Za-z0-9._~-]{8,512}$/;

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

/**
 * The action and the token in a query string, or null: only the three
 * actions, only a token of URL-safe characters.
 * @param {string} search - location.search
 * @returns {{action: string, token: string}|null}
 */
export function readAction(search) {
  const params = new URLSearchParams(search || "");
  const action = ACTIONS.find((name) => params.has(name));
  if (!action) {
    return null;
  }
  const token = (params.get(action) || "").trim();
  return TOKEN.test(token) ? { action, token } : null;
}

/**
 * Wires the manage page.
 * @param {Element} root - The element carrying data-subscription-manage
 * @param {Object} [deps] - `client`, `location` and `history`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initSubscriptionManage(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = doc.defaultView;
  const client = deps.client || getClient();
  const location = deps.location || (win && win.location) || { search: "", pathname: "/" };
  const history = deps.history === undefined ? win && win.history : deps.history;
  const labels = jsonIn(root, "[data-manage-labels]");
  const errorLabels = labels.errors || {};
  const status = root.querySelector("[data-manage-status]");
  const idle = root.querySelector("[data-manage-idle]");
  const unsubscribePanel = root.querySelector("[data-manage-unsubscribe-panel]");
  const preferences = root.querySelector("[data-manage-preferences]");
  const request = readAction(location.search);
  const path = request ? `${client.pathFor(FEATURE)}/${encodeURIComponent(request.token)}` : "";
  let retryAction = null;
  const retry = doc.createElement("button");
  retry.type = "button";
  retry.className = "post-tool";
  retry.dataset.manageRetry = "";
  retry.textContent = labels.retry || "Try again";
  retry.hidden = true;
  retry.addEventListener("click", () => retryAction?.());
  root.appendChild(retry);

  const setState = (state, message = "", alert = false) => {
    root.dataset.state = state;
    retry.hidden = state !== "error" || !retryAction;
    if (status) {
      status.textContent = message;
      status.hidden = message === "";
      status.setAttribute("role", alert ? "alert" : "status");
    }
  };

  const show = (panel) => {
    [idle, unsubscribePanel, preferences].forEach((element) => {
      if (element) {
        element.hidden = element !== panel;
      }
    });
  };

  const fail = (error, tokenRoute, action) => {
    const gone = tokenRoute && error && (error.kind === "not_found" || error.status === 410);
    retryAction = error?.retryable ? action : null;
    show(null);
    setState("error", gone ? labels.invalid_link || "" : describeError(error, errorLabels), true);
  };

  const busy = (on) => {
    root.setAttribute("aria-busy", on ? "true" : "false");
    root.querySelectorAll("button").forEach((button) => {
      button.disabled = on;
    });
  };

  const controller = {
    root,
    request,

    async confirm() {
      let tokenRoute = false;
      busy(true);
      show(null);
      setState("pending", labels.confirming || "");
      try {
        await client.feature(FEATURE);
        tokenRoute = true;
        const answer = await client.post(`${client.pathFor(FEATURE)}/confirm`, { token: request.token });
        setState("confirmed", labels.confirmed || "");
        return answer;
      } catch (error) {
        fail(error, tokenRoute, () => controller.confirm());
        return null;
      } finally {
        busy(false);
      }
    },

    async unsubscribe() {
      let tokenRoute = false;
      busy(true);
      setState("pending", labels.unsubscribing || "");
      try {
        await client.feature(FEATURE);
        tokenRoute = true;
        const answer = await client.delete(path);
        show(null);
        setState("unsubscribed", labels.unsubscribed || "");
        return answer;
      } catch (error) {
        fail(error, tokenRoute, () => controller.unsubscribe());
        return null;
      } finally {
        busy(false);
      }
    },

    /** Loads the subscription's topics into the preferences form. */
    async load() {
      let tokenRoute = false;
      busy(true);
      show(null);
      setState("loading", labels.loading || "");
      try {
        await client.feature(FEATURE);
        tokenRoute = true;
        const answer = await client.get(path);
        const topics = answer && answer.data && Array.isArray(answer.data.topics) ? answer.data.topics.map(String) : [];
        if (preferences) {
          preferences.querySelectorAll('[name="topics"]').forEach((box) => {
            box.checked = topics.includes(box.value);
          });
        }
        show(preferences);
        setState("loaded");
        return topics;
      } catch (error) {
        fail(error, tokenRoute, () => controller.load());
        return null;
      } finally {
        busy(false);
      }
    },

    async save() {
      const topics = Array.from(preferences.querySelectorAll('[name="topics"]:checked')).map((box) => box.value);
      busy(true);
      setState("pending", labels.saving || "");
      try {
        const answer = await client.patch(path, { topics });
        setState("saved", labels.saved || "");
        return answer;
      } catch (error) {
        setState("error", describeError(error, errorLabels), true);
        return null;
      } finally {
        busy(false);
      }
    }
  };

  root.querySelectorAll("[data-manage-unsubscribe]").forEach((button) => {
    button.addEventListener("click", () => controller.unsubscribe());
  });
  if (preferences) {
    preferences.addEventListener("submit", (event) => {
      event.preventDefault();
      controller.save();
    });
  }

  if (!client.enabled) {
    show(null);
    setState("disabled", errorLabels.disabled || "");
    return controller;
  }
  if (!request) {
    show(idle);
    setState("idle");
    return controller;
  }

  // The token has been read: take it out of the address bar.
  if (history && typeof history.replaceState === "function") {
    history.replaceState(null, "", location.pathname);
  }

  if (request.action === "confirm") {
    controller.confirm();
  } else if (request.action === "manage") {
    controller.load();
  } else {
    // Ending a subscription takes a press of the button, never just opening the link.
    show(unsubscribePanel);
    setState("idle");
  }
  return controller;
}

/**
 * Wires every manage block on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initSubscriptionManagers(doc = document) {
  return Array.from(doc.querySelectorAll("[data-subscription-manage]")).map((root) => initSubscriptionManage(root));
}
