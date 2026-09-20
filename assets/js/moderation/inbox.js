/**
 * @fileoverview The moderation inbox (#257): one place to review what the
 * self-hosted features receive, comments awaiting approval or flagged as
 * spam, correction reports, abuse reports, and to act on them through the
 * moderation API (docs/moderation.md).
 *
 * This page is a shell. It holds no secret and protects nothing: a static
 * site cannot. Who may read the queue and act on it is decided by the
 * moderation service, or the identity-aware proxy in front of it, on every
 * request; the browser only sends the session it was given (a cookie, with
 * `credentials: include`). A 401 shows a way to sign in, a 403 says the
 * account may not moderate, and neither reveals anything.
 * @module moderation/inbox
 */

import { createClient, describeError } from "../dynamic-services/client.js";
import { createSubmission } from "../dynamic-services/form-state.js";

export const FEATURE = "moderation";
export const TYPES = ["comment", "correction", "abuse"];

/** What each action leaves an item as. */
export const RESULT = {
  approve: "approved",
  spam: "spam",
  hide: "hidden",
  delete: "deleted",
  reviewed: "reviewed",
  accept: "accepted",
  reject: "rejected",
  resolve: "resolved",
  dismiss: "dismissed"
};

/** The actions a moderator can take, by the item's type and status. */
export const ACTIONS = {
  comment: {
    pending: ["approve", "spam", "delete"],
    approved: ["hide", "spam", "delete"],
    spam: ["approve", "delete"],
    hidden: ["approve", "delete"]
  },
  correction: {
    new: ["reviewed", "accept", "reject"],
    reviewed: ["accept", "reject"],
    accepted: ["resolve", "reject"]
  },
  abuse: {
    open: ["dismiss", "hide", "delete"]
  }
};

/** The queue: what awaits a decision, which is what a listing without a status returns. */
export const QUEUE = {
  comment: ["pending"],
  correction: ["new", "reviewed", "accepted"],
  abuse: ["open"]
};

const SAFE_URL = /^https?:\/\//i;
const AUTH = new Set(["unauthorized", "forbidden"]);
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



function text(value) {
  return typeof value === "string" ? value : "";
}

/** The actions open to an item as it stands. */
export function actionsFor(item) {
  const byStatus = ACTIONS[item.type] || {};
  return byStatus[item.status] || [];
}

/**
 * One entry of the service's answer as the inbox shows it, or null when it
 * has no id or is of a type the inbox does not know. Everything is kept as
 * text; a link is kept only when it is http(s).
 * @param {*} entry
 * @returns {Object|null}
 */
export function normalizeItem(entry) {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return null;
  }
  const type = text(entry.type).toLowerCase();
  if (entry.id === null || entry.id === undefined || !TYPES.includes(type)) {
    return null;
  }
  const author = entry.author && typeof entry.author === "object" ? entry.author : {};
  const context = entry.context && typeof entry.context === "object" ? entry.context : {};
  const parent = context.parent && typeof context.parent === "object" ? context.parent : null;
  const resolution = entry.resolution && typeof entry.resolution === "object" ? entry.resolution : {};
  const history = Array.isArray(entry.history) ? entry.history : [];
  return {
    id: String(entry.id),
    type,
    status: text(entry.status).toLowerCase(),
    created_at: text(entry.created_at),
    path: text(entry.path),
    title: text(entry.title),
    author: { name: text(author.name), email: text(author.email) },
    body: text(entry.body) || text(entry.message),
    category: text(entry.category),
    section: text(entry.section),
    quote: text(entry.quote),
    reason: text(entry.reason),
    parent: parent ? { author: text(parent.author && parent.author.name), body: text(parent.body) } : null,
    link: SAFE_URL.test(text(resolution.url)) ? resolution.url : "",
    history: history
      .filter((step) => step && typeof step === "object")
      .map((step) => ({ action: text(step.action), at: text(step.at), moderator: text(step.moderator), note: text(step.note) }))
  };
}

/**
 * The query string of a listing, from the filters that are set.
 * @param {Object} filters - `type`, `status`, `path`, `category`, `since`, `q`
 * @param {string} [cursor]
 * @returns {string} "" or "?…"
 */
export function buildQuery(filters = {}, cursor = "") {
  const params = new URLSearchParams();
  ["type", "status", "path", "category", "since", "q"].forEach((name) => {
    const value = text(filters[name]).trim();
    if (value && value !== "all") {
      params.set(name, value);
    }
  });
  if (cursor) {
    params.set("cursor", cursor);
  }
  const query = params.toString();
  return query ? `?${query}` : "";
}

function formatDate(value, lang) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  try {
    return date.toLocaleString(lang || undefined, { dateStyle: "medium", timeStyle: "short" });
  } catch (error) {
    return date.toISOString();
  }
}

function add(doc, parent, tag, className, content) {
  const element = doc.createElement(tag);
  if (className) {
    element.className = className;
  }
  if (content !== undefined) {
    element.textContent = content;
  }
  parent.appendChild(element);
  return element;
}

/**
 * One item as DOM, built from text nodes only, with the buttons for the
 * actions open to it.
 * @param {Document} doc
 * @param {Object} item - A normalized item
 * @param {Object} [options] - `labels`, `lang`, `siteUrl`, `onAction`
 * @returns {HTMLLIElement}
 */
export function renderItem(doc, item, options = {}) {
  const { labels = {}, lang, siteUrl = "", onAction } = options;
  const types = labels.types || {};
  const statuses = labels.statuses || {};
  const actions = labels.actions || {};
  const element = doc.createElement("li");
  element.className = `moderation-item moderation-item--${item.type}`;
  element.dataset.itemId = item.id;
  element.dataset.itemStatus = item.status;

  const card = add(doc, element, "article", "moderation-item__card");
  const meta = add(doc, card, "header", "moderation-item__meta");
  add(doc, meta, "span", "moderation-item__type", types[item.type] || item.type);
  add(doc, meta, "span", "moderation-item__status", statuses[item.status] || item.status);
  if (item.category) {
    add(doc, meta, "span", "moderation-item__category", (labels.categories || {})[item.category] || item.category);
  }
  if (item.created_at) {
    const time = add(doc, meta, "time", "moderation-item__time", formatDate(item.created_at, lang));
    time.dateTime = item.created_at;
  }

  if (item.path) {
    const where = add(doc, card, "p", "moderation-item__where");
    const link = add(doc, where, "a", "", item.title || item.path);
    // Only a path on this site is linked; anything else stays text.
    if (item.path.startsWith("/") && !item.path.startsWith("//")) {
      link.href = `${siteUrl.replace(/\/+$/, "")}${item.path}${item.section ? `#${encodeURIComponent(item.section)}` : ""}`;
    }
  }
  if (item.author.name || item.author.email) {
    add(doc, card, "p", "moderation-item__author", [item.author.name, item.author.email].filter(Boolean).join(" · "));
  }
  if (item.parent) {
    const context = add(doc, card, "blockquote", "moderation-item__context");
    add(doc, context, "p", "", `${labels.in_reply_to || "In reply to"} ${item.parent.author || ""}`.trim());
    add(doc, context, "p", "", item.parent.body);
  }
  if (item.quote) {
    add(doc, card, "blockquote", "moderation-item__quote", item.quote);
  }
  if (item.reason) {
    add(doc, card, "p", "moderation-item__reason", item.reason);
  }
  const body = add(doc, card, "div", "moderation-item__body");
  item.body.split(/\n{2,}/).forEach((paragraph) => add(doc, body, "p", "", paragraph));

  if (item.link) {
    const resolved = add(doc, card, "p", "moderation-item__link");
    const anchor = add(doc, resolved, "a", "", item.link);
    anchor.href = item.link;
    anchor.rel = "noopener";
  }
  if (item.history.length > 0) {
    const trail = add(doc, card, "ol", "moderation-item__history");
    item.history.forEach((step) => {
      const line = [actions[step.action] || step.action, step.moderator, step.at ? formatDate(step.at, lang) : "", step.note]
        .filter(Boolean)
        .join(" · ");
      add(doc, trail, "li", "", line);
    });
  }

  const open = actionsFor(item);
  if (open.length > 0 && onAction) {
    const controls = add(doc, card, "div", "moderation-item__actions");
    const noteId = `moderation-note-${item.id}`;
    const noteLabel = add(doc, controls, "label", "moderation-item__note-label", labels.note || "Note");
    noteLabel.htmlFor = noteId;
    const note = add(doc, controls, "input", "moderation-item__note");
    note.type = "text";
    note.id = noteId;
    note.name = "note";
    let link = null;
    if (open.includes("resolve")) {
      const linkId = `moderation-link-${item.id}`;
      const linkLabel = add(doc, controls, "label", "moderation-item__note-label", labels.link || "Issue, pull request or revision");
      linkLabel.htmlFor = linkId;
      link = add(doc, controls, "input", "moderation-item__note");
      link.type = "url";
      link.id = linkId;
      link.name = "link";
    }
    const buttons = add(doc, controls, "div", "moderation-item__buttons");
    open.forEach((action) => {
      const button = add(doc, buttons, "button", "post-tool", actions[action] || action);
      button.type = "button";
      button.dataset.moderationAction = action;
      button.addEventListener("click", () => onAction(item, action, { note: note.value.trim(), link: link ? link.value.trim() : "" }));
    });
  }
  const message = add(doc, card, "p", "moderation-item__message");
  message.setAttribute("data-item-message", "");
  message.setAttribute("role", "status");
  message.hidden = true;
  return element;
}

/**
 * Wires the inbox.
 * @param {Element} root - The element carrying data-moderation-inbox
 * @param {Object} [deps] - `client`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initModerationInbox(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = doc.defaultView;
  const settings = (win && win.DatalogDynamicServices) || {};
  const endpoint = root.dataset.moderationEndpoint || "";
  // The moderator's session goes with every request; the public features' setting does not apply here.
  const client =
    deps.client ||
    createClient({
      ...settings,
      features: endpoint ? {} : settings.features,
      base_url: endpoint || settings.base_url || "",
      credentials: root.dataset.moderationCredentials || "include"
    });
  const submission = createSubmission();
  const labels = jsonIn(root, "[data-moderation-labels]");
  const errorLabels = labels.errors || {};
  const lang = doc.documentElement.lang || undefined;
  const siteUrl = root.dataset.moderationSite || "";
  const status = root.querySelector("[data-moderation-status]");
  const list = root.querySelector("[data-moderation-list]");
  const filtersForm = root.querySelector("[data-moderation-filters]");
  const more = root.querySelector("[data-moderation-more]");
  const signIn = root.querySelector("[data-moderation-sign-in]");
  let cursor = "";
  let loading = false;
  let sequence = 0;
  let activeFilters = {};
  let revision = 0;

  const setState = (state, message = "", alert = false) => {
    root.dataset.state = state;
    root.setAttribute("aria-busy", state === "loading" ? "true" : "false");
    if (status) {
      status.textContent = message;
      status.hidden = message === "";
      status.setAttribute("role", alert ? "alert" : "status");
    }
    if (signIn) {
      signIn.hidden = state !== "unauthorized";
    }
  };

  const filters = () => {
    const values = {};
    if (filtersForm) {
      new FormData(filtersForm).forEach((value, name) => {
        values[name] = String(value);
      });
    }
    return values;
  };

  const refuse = (error) => {
    list.textContent = "";
    if (more) {
      more.hidden = true;
    }
    if (error && error.kind === "unauthorized") {
      setState("unauthorized", labels.unauthorized || "", true);
    } else if (error && error.kind === "forbidden") {
      setState("forbidden", labels.forbidden || "", true);
    } else if (error && OFF.has(error.kind)) {
      setState("disabled", describeError(error, errorLabels));
    } else {
      setState("error", describeError(error, errorLabels), true);
    }
  };

  const itemMessage = (element, message, alert = false) => {
    const slot = element.querySelector("[data-item-message]");
    if (slot) {
      slot.textContent = message;
      slot.hidden = message === "";
      slot.setAttribute("role", alert ? "alert" : "status");
    }
  };

  /** Whether an item still belongs in the listing on screen: the status asked for, or the queue. */
  const matchesFilter = (item) => {
    const wanted = text(activeFilters.status).trim();
    return wanted ? wanted === item.status : (QUEUE[item.type] || []).includes(item.status);
  };

  const controller = {
    root,
    client,

    /** Loads the queue under the current filters; `append` continues from the cursor. */
    async load(append = false, requestedFilters = append ? activeFilters : filters()) {
      if (loading && append) {
        return null;
      }
      const request = ++sequence;
      const readRevision = revision;
      loading = true;
      if (!append) {
        cursor = "";
      }
      setState("loading", labels.loading || "");
      try {
        await client.feature(FEATURE);
        const answer = await client.get(`${client.pathFor(FEATURE)}/items${buildQuery(requestedFilters, append ? cursor : "")}`);
        if (request !== sequence) return null;
        // An action completed after this read began. Fetch the same page again
        // so its filters and cursor remain valid without restoring stale items.
        if (readRevision !== revision) {
          loading = false;
          return controller.load(append, requestedFilters);
        }
        activeFilters = requestedFilters;
        const data = answer && answer.data && typeof answer.data === "object" ? answer.data : {};
        const items = (Array.isArray(data.items) ? data.items : []).map(normalizeItem).filter(Boolean);
        if (!append) {
          list.textContent = "";
        }
        items.forEach((item) => list.appendChild(renderItem(doc, item, { labels, lang, siteUrl, onAction: controller.act })));
        cursor = text(data.next_cursor);
        if (more) {
          more.hidden = cursor === "";
        }
        const shown = list.children.length;
        setState(shown > 0 ? "loaded" : "empty", shown > 0 ? "" : labels.empty || "");
        return items;
      } catch (error) {
        if (request !== sequence) return null;
        if (readRevision !== revision) {
          loading = false;
          return controller.load(append, requestedFilters);
        }
        refuse(error);
        return null;
      } finally {
        if (request === sequence) loading = false;
      }
    },

    /**
     * Takes an action on an item. Nothing changes on the page unless the
     * service says it did: a failure leaves the item as it was, with the
     * reason next to it.
     */
    async act(item, action, extra = {}) {
      const element = Array.from(list.children).find((child) => child.dataset.itemId === item.id);
      if (!element || !actionsFor(item).includes(action)) {
        return null;
      }
      if (action === "resolve" && !SAFE_URL.test(extra.link || "")) {
        itemMessage(element, labels.link_required || "", true);
        return null;
      }
      const buttons = Array.from(element.querySelectorAll("button"));
      buttons.forEach((button) => {
        button.disabled = true;
      });
      element.setAttribute("aria-busy", "true");
      itemMessage(element, labels.working || "");
      const payload = { action };
      if (extra.note) {
        payload.note = extra.note;
      }
      if (action === "resolve") {
        payload.link = extra.link;
      }
      try {
        const answer = await client.post(`${client.pathFor(FEATURE)}/items/${encodeURIComponent(item.id)}/actions`, payload, {
          idempotencyKey: submission.key(payload, item.id)
        });
        submission.clear(item.id);
        revision += 1;
        const returned = normalizeItem(answer && answer.data && answer.data.item);
        const updated = returned || { ...item, status: RESULT[action] || item.status };
        // A refresh can replace the node while the action is in flight.
        const current = Array.from(list.children).find((child) => child.dataset.itemId === item.id);
        if (!current) return updated;
        const done = (labels.done || "{{action}}").split("{{action}}").join((labels.actions || {})[action] || action);
        if (matchesFilter(updated)) {
          const fresh = renderItem(doc, updated, { labels, lang, siteUrl, onAction: controller.act });
          list.replaceChild(fresh, current);
          itemMessage(fresh, done);
        } else {
          current.remove();
          setState(list.children.length > 0 ? "loaded" : "empty", list.children.length > 0 ? done : `${done} ${labels.empty || ""}`.trim());
        }
        return updated;
      } catch (error) {
        if (error && AUTH.has(error.kind)) {
          refuse(error);
        } else {
          element.setAttribute("aria-busy", "false");
          buttons.forEach((button) => {
            button.disabled = false;
          });
          itemMessage(element, describeError(error, errorLabels), true);
        }
        return null;
      }
    }
  };

  if (filtersForm) {
    filtersForm.addEventListener("submit", (event) => {
      event.preventDefault();
      controller.load();
    });
    filtersForm.addEventListener("reset", () => {
      // The fields clear after the event; load on the next turn.
      Promise.resolve().then(() => controller.load());
    });
  }
  if (more) {
    more.addEventListener("click", () => controller.load(true));
  }

  if (!client.enabled) {
    setState("disabled", errorLabels.disabled || "");
    return controller;
  }
  controller.load();
  return controller;
}

/**
 * Wires every inbox on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initModerationInboxes(doc = document) {
  return Array.from(doc.querySelectorAll("[data-moderation-inbox]")).map((root) => initModerationInbox(root));
}
