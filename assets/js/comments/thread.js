/**
 * @fileoverview The comments thread of the `api` provider (#253): the
 * discussion under an article, read from and written to the site's own
 * backend through the dynamic services (docs/dynamic-services.md) instead
 * of Giscus, utterances or Disqus. Everything the service returns is put on
 * the page as text; nothing is parsed as HTML.
 * @module comments/thread
 */

import { createClient, describeError, getClient } from "../dynamic-services/client.js";
import { createSubmission, readForm, setFormState, showFailure } from "../dynamic-services/form-state.js";

export const FEATURE = "comments";
export const MIN_BODY = 3;
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



function interpolate(text, values) {
  return Object.keys(values).reduce((memo, key) => memo.split(`{{${key}}}`).join(values[key]), text);
}

function formatDate(value, lang) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return String(value || "");
  }
  try {
    return date.toLocaleString(lang || undefined, { dateStyle: "medium", timeStyle: "short" });
  } catch (error) {
    return date.toISOString();
  }
}

/**
 * The comments as a tree, oldest first at every level. A reply whose parent
 * is not in the list, or every comment when replies are off, sits at the top.
 * @param {Object[]} comments
 * @param {boolean} [replies]
 * @returns {{comment: Object, replies: Object[]}[]}
 */
export function threadOf(comments, replies = true) {
  const list = Array.isArray(comments) ? comments.filter((comment) => comment && typeof comment === "object") : [];
  const byId = new Map();
  list.forEach((comment) => byId.set(String(comment.id), { comment, replies: [] }));
  const roots = [];
  byId.forEach((node) => {
    const parentId = node.comment.parent_id;
    const parent = replies && parentId !== null && parentId !== undefined ? byId.get(String(parentId)) : null;
    if (parent && parent !== node) {
      parent.replies.push(node);
    } else {
      roots.push(node);
    }
  });
  const byDate = (a, b) => (Date.parse(a.comment.created_at) || 0) - (Date.parse(b.comment.created_at) || 0);
  const sort = (nodes) => {
    nodes.sort(byDate);
    nodes.forEach((node) => sort(node.replies));
    return nodes;
  };
  return sort(roots);
}

/**
 * One comment as DOM, built from text nodes only. The author's link is kept
 * when it is an http(s) address; a pending comment carries its badge and no
 * reply button.
 * @param {Document} doc
 * @param {Object} comment
 * @param {Object} [options] - `labels`, `lang`, `replies`, `onReply`
 * @returns {HTMLLIElement}
 */
export function renderComment(doc, comment, options = {}) {
  const { labels = {}, lang, replies = false, onReply } = options;
  const pending = comment.status === "pending";
  const item = doc.createElement("li");
  item.className = pending ? "comment comment--pending" : "comment";
  if (comment.id !== null && comment.id !== undefined) {
    item.id = `comment-${comment.id}`;
  }
  const card = doc.createElement("article");
  card.className = "comment__card";

  const meta = doc.createElement("header");
  meta.className = "comment__meta";
  const author = comment.author && typeof comment.author === "object" ? comment.author : {};
  const name = String(author.name || "").trim() || labels.anonymous || "Anonymous";
  let who;
  if (SAFE_URL.test(String(author.url || ""))) {
    who = doc.createElement("a");
    who.href = author.url;
    who.rel = "nofollow noopener ugc";
  } else {
    who = doc.createElement("span");
  }
  who.className = "comment__author";
  who.textContent = name;
  meta.appendChild(who);
  if (comment.created_at) {
    const time = doc.createElement("time");
    time.className = "comment__time";
    time.dateTime = String(comment.created_at);
    time.textContent = formatDate(comment.created_at, lang);
    meta.appendChild(time);
  }
  if (pending) {
    const badge = doc.createElement("span");
    badge.className = "comment__pending";
    badge.textContent = labels.pending || "Awaiting moderation";
    meta.appendChild(badge);
  }
  card.appendChild(meta);

  const body = doc.createElement("div");
  body.className = "comment__body";
  String(comment.body || "")
    .split(/\n{2,}/)
    .forEach((paragraph) => {
      const p = doc.createElement("p");
      paragraph.split("\n").forEach((line, index) => {
        if (index > 0) {
          p.appendChild(doc.createElement("br"));
        }
        p.appendChild(doc.createTextNode(line));
      });
      body.appendChild(p);
    });
  card.appendChild(body);

  if (replies && onReply && !pending && comment.id !== null && comment.id !== undefined) {
    const button = doc.createElement("button");
    button.type = "button";
    button.className = "comment__reply post-tool";
    button.textContent = labels.reply || "Reply";
    button.addEventListener("click", () => onReply(comment));
    card.appendChild(button);
  }
  item.appendChild(card);
  return item;
}

function repliesList(doc, item) {
  let list = item.querySelector(":scope > .comments-thread__replies");
  if (!list) {
    list = doc.createElement("ol");
    list.className = "comments-thread__replies";
    item.appendChild(list);
  }
  return list;
}

function fill(doc, list, nodes, options) {
  nodes.forEach((node) => {
    const item = renderComment(doc, node.comment, options);
    if (node.replies.length > 0) {
      fill(doc, repliesList(doc, item), node.replies, options);
    }
    list.appendChild(item);
  });
}

/**
 * What the form sends: the page, the parent when replying, the author
 * (email and website only when given) and the text. The honeypot is left out.
 * @param {Object} fields - readForm's result
 * @param {string} path - The page's path, as the service keys comments
 * @returns {Object}
 */
export function buildComment(fields, path) {
  const author = { name: fields.name || "" };
  if (fields.email) {
    author.email = fields.email;
  }
  if (fields.url) {
    author.url = fields.url;
  }
  return { path, parent_id: fields.parent_id || null, author, body: fields.body || "" };
}

/**
 * Checks before a request: a name, an email and a website that look like
 * one when given, some text, and an empty honeypot.
 * @param {Object} comment
 * @param {Object} fields - The raw fields, for the honeypot
 * @param {Object} labels
 * @returns {Object|null} Field errors, or null when the comment can go
 */
export function validate(comment, fields, labels = {}) {
  const errors = {};
  if (!comment.author.name) {
    errors.name = labels.name_required || "Say who you are.";
  }
  if (comment.author.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(comment.author.email)) {
    errors.email = labels.email_invalid || "That does not look like an email address.";
  }
  if (comment.author.url && !SAFE_URL.test(comment.author.url)) {
    errors.url = labels.url_invalid || "A website address starts with http:// or https://.";
  }
  if (comment.body.trim().length < MIN_BODY) {
    errors.body = labels.body_short || "Say a little more.";
  }
  if (fields.website) {
    errors.website = "spam";
  }
  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * Wires one thread: loads the comments when the section comes near the
 * viewport, and posts the form.
 * @param {Element} root - The element carrying data-comments-thread
 * @param {Object} [deps] - `client`, `window` and `immediate`, replaceable in tests
 * @returns {Object} The controller, for tests
 */
export function initCommentsThread(root, deps = {}) {
  const doc = root.ownerDocument;
  const win = deps.window || doc.defaultView;
  const endpoint = root.dataset.commentsEndpoint || "";
  const client =
    deps.client ||
    (endpoint ? createClient({ ...((win && win.DatalogDynamicServices) || {}), base_url: endpoint }) : getClient());
  const path = root.dataset.commentsPath || "/";
  const replies = root.dataset.commentsReplies !== "false";
  const labels = jsonIn(root, "[data-comments-labels]");
  const errorLabels = labels.errors || {};
  const lang = doc.documentElement.lang || undefined;
  const status = root.querySelector("[data-comments-status]");
  const list = root.querySelector("[data-comments-list]");
  const form = root.querySelector("form");
  const submission = createSubmission(form);
  const parentField = form ? form.elements.namedItem("parent_id") : null;
  const replying = root.querySelector("[data-comments-replying]");
  const replyingTo = root.querySelector("[data-comments-replying-to]");
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
      button.setAttribute("data-comments-retry", "");
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

  const onReply = (comment) => {
    if (!parentField) {
      return;
    }
    parentField.value = String(comment.id);
    if (replyingTo) {
      const author = comment.author && comment.author.name ? comment.author.name : labels.anonymous || "Anonymous";
      replyingTo.textContent = interpolate(labels.replying_to || "Replying to {{name}}", { name: author });
    }
    if (replying) {
      replying.hidden = false;
    }
    const body = form.elements.namedItem("body");
    if (body && typeof body.focus === "function") {
      body.focus();
    }
  };

  const cancelReply = () => {
    if (parentField) {
      parentField.value = "";
    }
    if (replying) {
      replying.hidden = true;
    }
  };

  const renderOptions = { labels, lang, replies, onReply };

  /** Puts a new comment where it belongs: under its parent, or at the end. */
  const place = (item, parentId) => {
    const parent =
      replies && parentId !== null && parentId !== undefined ? list.querySelector(`#comment-${CSS.escape(String(parentId))}`) : null;
    (parent ? repliesList(doc, parent) : list).appendChild(item);
    list.hidden = false;
    if (root.dataset.state === "empty") {
      setState("loaded");
    }
  };

  const controller = {
    root,
    form,
    reply: onReply,
    cancelReply,

    /** Fetches the thread. Resolves the comments, or null when it could not. */
    async load() {
      if (loading) {
        return null;
      }
      loading = true;
      setState("loading", labels.loading || "");
      try {
        await ensureAvailable();
        const answer = await client.get(`${client.pathFor(FEATURE)}?path=${encodeURIComponent(path)}`);
        const comments = answer && answer.data && Array.isArray(answer.data.comments) ? answer.data.comments : [];
        list.textContent = "";
        const nodes = threadOf(comments, replies);
        fill(doc, list, nodes, renderOptions);
        list.hidden = nodes.length === 0;
        setState(nodes.length > 0 ? "loaded" : "empty", nodes.length > 0 ? "" : labels.empty || "");
        loaded = true;
        return comments;
      } catch (error) {
        if (error && OFF.has(error.kind)) {
          // No backend, the feature off, or another API version: nothing to show or send.
          setState("disabled", describeError(error, errorLabels));
          if (form) {
            form.hidden = true;
          }
        } else {
          setState("error", describeError(error, errorLabels), { alert: true, retry: true });
        }
        return null;
      } finally {
        loading = false;
      }
    },

    /** Posts the form. Resolves the service's answer, or null when nothing was sent. */
    async submit() {
      const fields = readForm(form);
      const comment = buildComment(fields, path);
      const errors = validate(comment, fields, labels);
      if (errors) {
        if (errors.website) {
          // A filled honeypot is a bot: pretend it is awaiting moderation and send nothing.
          setFormState(form, "success", labels.posted_pending || "");
          return null;
        }
        setFormState(form, "invalid", errorLabels.invalid || "", errors);
        return null;
      }
      setFormState(form, "pending", labels.sending || "");
      try {
        await ensureAvailable();
        const answer = await client.post(client.pathFor(FEATURE), comment, { idempotencyKey: submission.key(comment) });
        const data = answer && answer.data && typeof answer.data === "object" ? answer.data : {};
        const posted = data.comment && typeof data.comment === "object" ? data.comment : null;
        const pending = data.status === "pending" || (posted !== null && posted.status === "pending");
        if (posted) {
          place(renderComment(doc, pending ? { ...posted, status: "pending" } : posted, renderOptions), posted.parent_id);
        }
        submission.clear();
        form.reset();
        cancelReply();
        setFormState(form, "success", pending ? labels.posted_pending || "" : labels.posted || "");
        return answer;
      } catch (error) {
        showFailure(form, error, errorLabels);
        return null;
      }
    }
  };

  if (form) {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      controller.submit();
    });
    root.querySelectorAll("[data-comments-cancel-reply]").forEach((button) => {
      button.addEventListener("click", cancelReply);
    });
  }

  // The thread is fetched when the reader gets near it, not with the article.
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
 * Wires every thread on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initCommentsThreads(doc = document) {
  return Array.from(doc.querySelectorAll("[data-comments-thread]")).map((root) => initCommentsThread(root));
}
