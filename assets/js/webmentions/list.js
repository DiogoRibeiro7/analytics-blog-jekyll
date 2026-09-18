/**
 * @fileoverview "Mentioned elsewhere" (#258): the links, replies and reposts
 * other websites sent about an article, as the site's own backend reports
 * them through the dynamic services (docs/dynamic-services.md). Everything
 * here is untrusted, external content: only what the receiver verified is
 * shown, only as text, and only from http(s) sources.
 * @module webmentions/list
 */

import { describeError, getClient } from "../dynamic-services/client.js";

export const FEATURE = "webmentions";
export const DEFAULT_TYPES = ["mention", "reply"];
export const KNOWN_TYPES = ["mention", "reply", "repost", "like"];
export const MAX_TITLE = 200;
export const MAX_EXCERPT = 280;
const SAFE_URL = /^https?:\/\//i;
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

function text(value, max) {
  if (typeof value !== "string") {
    return "";
  }
  const clean = value.replace(/\s+/g, " ").trim();
  return clean.length > max ? `${clean.slice(0, max - 1).trimEnd()}…` : clean;
}

function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch (error) {
    return "";
  }
}

/**
 * One entry of the service's answer as the list shows it, or null when it
 * is not to be shown: not an object, not verified by the receiver, without
 * an http(s) source, or of a type the site does not list. Text fields are
 * trimmed and cut; the author's link is kept only when it is http(s).
 * @param {*} entry
 * @param {string[]} [types] - The types the site shows
 * @returns {Object|null}
 */
export function normalizeMention(entry, types = DEFAULT_TYPES) {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return null;
  }
  const source = typeof entry.source === "string" ? entry.source.trim() : "";
  const type = typeof entry.type === "string" ? entry.type.trim().toLowerCase() : "mention";
  if (entry.verified !== true || !SAFE_URL.test(source) || !types.includes(type)) {
    return null;
  }
  const author = entry.author && typeof entry.author === "object" ? entry.author : {};
  const authorUrl = typeof author.url === "string" && SAFE_URL.test(author.url.trim()) ? author.url.trim() : "";
  const published = typeof entry.published_at === "string" && !Number.isNaN(Date.parse(entry.published_at)) ? entry.published_at : "";
  return {
    id: entry.id === null || entry.id === undefined ? "" : String(entry.id),
    source,
    host: hostOf(source),
    type,
    title: text(entry.title, MAX_TITLE),
    excerpt: text(entry.excerpt, MAX_EXCERPT),
    author: { name: text(author.name, 120), url: authorUrl },
    published_at: published
  };
}

/**
 * The mentions of an answer, filtered and newest first.
 * @param {*} data
 * @param {string[]} [types]
 * @returns {Object[]}
 */
export function mentionsIn(data, types = DEFAULT_TYPES) {
  const list = data && typeof data === "object" && Array.isArray(data.mentions) ? data.mentions : [];
  return list
    .map((entry) => normalizeMention(entry, types))
    .filter(Boolean)
    .sort((a, b) => b.published_at.localeCompare(a.published_at));
}

function formatDate(value, lang) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  try {
    return date.toLocaleDateString(lang || undefined, { dateStyle: "medium" });
  } catch (error) {
    return date.toISOString().slice(0, 10);
  }
}

/**
 * One mention as DOM, built from text nodes only.
 * @param {Document} doc
 * @param {Object} mention - A normalized mention
 * @param {Object} [options] - `labels` and `lang`
 * @returns {HTMLLIElement}
 */
export function renderMention(doc, mention, options = {}) {
  const { labels = {}, lang } = options;
  const types = labels.types || {};
  const item = doc.createElement("li");
  item.className = `webmention webmention--${mention.type}`;
  if (mention.id) {
    item.dataset.mentionId = mention.id;
  }

  const kind = doc.createElement("span");
  kind.className = "webmention__type";
  kind.textContent = types[mention.type] || mention.type;
  item.appendChild(kind);

  const link = doc.createElement("a");
  link.className = "webmention__title";
  link.href = mention.source;
  link.rel = "nofollow noopener ugc";
  link.textContent = mention.title || mention.host || mention.source;
  item.appendChild(link);

  const meta = doc.createElement("span");
  meta.className = "webmention__meta";
  if (mention.author.name) {
    let who;
    if (mention.author.url) {
      who = doc.createElement("a");
      who.href = mention.author.url;
      who.rel = "nofollow noopener ugc";
    } else {
      who = doc.createElement("span");
    }
    who.className = "webmention__author";
    who.textContent = mention.author.name;
    meta.appendChild(who);
  }
  // Without a title the link already reads as the host.
  if (mention.host && mention.title) {
    const host = doc.createElement("span");
    host.className = "webmention__host";
    host.textContent = mention.host;
    meta.appendChild(host);
  }
  if (mention.published_at) {
    const time = doc.createElement("time");
    time.className = "webmention__time";
    time.dateTime = mention.published_at;
    time.textContent = formatDate(mention.published_at, lang);
    meta.appendChild(time);
  }
  if (meta.childNodes.length > 0) {
    item.appendChild(meta);
  }

  if (mention.excerpt) {
    const excerpt = doc.createElement("p");
    excerpt.className = "webmention__excerpt";
    excerpt.textContent = mention.excerpt;
    item.appendChild(excerpt);
  }
  return item;
}

/**
 * Wires one "Mentioned elsewhere" section.
 * @param {Element} root - The element carrying data-webmentions
 * @param {Object} [deps] - `client`, `window` and `immediate`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initWebmentions(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = deps.window || doc.defaultView;
  const client = deps.client || getClient();
  const target = root.dataset.webmentionsTarget || "";
  const types = (root.dataset.webmentionsTypes || DEFAULT_TYPES.join(","))
    .split(",")
    .map((type) => type.trim().toLowerCase())
    .filter((type) => KNOWN_TYPES.includes(type));
  const labels = jsonIn(root, "[data-webmentions-labels]");
  const errorLabels = labels.errors || {};
  const lang = doc.documentElement.lang || undefined;
  const status = root.querySelector("[data-webmentions-status]");
  const list = root.querySelector("[data-webmentions-list]");
  let availability = null;
  let loading = false;
  let loaded = false;

  const setState = (state, message = "", options = {}) => {
    root.dataset.state = state;
    if (!status) {
      return;
    }
    status.textContent = message;
    status.hidden = message === "";
    status.setAttribute("role", options.alert ? "alert" : "status");
    if (options.retry) {
      const button = doc.createElement("button");
      button.type = "button";
      button.className = "post-tool";
      button.setAttribute("data-webmentions-retry", "");
      button.textContent = labels.retry || "Try again";
      button.addEventListener("click", () => controller.load());
      status.appendChild(doc.createTextNode(" "));
      status.appendChild(button);
    }
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
    types,

    /** Fetches the mentions of this page. Resolves them, or null when it could not. */
    async load() {
      if (loading) {
        return null;
      }
      loading = true;
      setState("loading", labels.loading || "");
      try {
        await ensureAvailable();
        const answer = await client.get(`${client.pathFor(FEATURE)}?target=${encodeURIComponent(target)}`);
        const mentions = mentionsIn(answer && answer.data, types);
        list.textContent = "";
        mentions.forEach((mention) => list.appendChild(renderMention(doc, mention, { labels, lang })));
        list.hidden = mentions.length === 0;
        setState(mentions.length > 0 ? "loaded" : "empty", mentions.length > 0 ? "" : labels.empty || "");
        loaded = true;
        return mentions;
      } catch (error) {
        if (error && OFF.has(error.kind)) {
          // Nothing to read: the section has nothing to say to the reader.
          setState("disabled");
          root.hidden = true;
        } else {
          setState("error", describeError(error, errorLabels), { alert: true, retry: true });
        }
        return null;
      } finally {
        loading = false;
      }
    }
  };

  // The mentions are fetched when the reader gets near the section, not with the article.
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

/**
 * Wires every "Mentioned elsewhere" section on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initAllWebmentions(doc = document) {
  return Array.from(doc.querySelectorAll("[data-webmentions]")).map((root) => initWebmentions(root));
}
