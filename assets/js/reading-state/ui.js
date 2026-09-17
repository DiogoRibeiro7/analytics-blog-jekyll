/**
 * @fileoverview The reading-state controls (#260): the bookmark button, the
 * "resume where you left off" prompt, the selection toolbar and the panel of
 * private highlights on a post, and the list of saved articles on a page.
 * Everything reads and writes the local store; nothing leaves the browser.
 * @module reading-state/ui
 */

import { describeRange, locate } from "./anchors.js";
import { paint } from "./highlights.js";
import { trackProgress, worthResuming } from "./progress.js";
import { createStore, emptyRecord } from "./storage.js";

const EDITABLE = new Set(["INPUT", "TEXTAREA", "SELECT"]);

function fill(template, values) {
  return Object.keys(values).reduce((text, key) => text.split(`{{${key}}}`).join(String(values[key])), template || "");
}

function newId() {
  const crypto = globalThis.crypto;
  if (crypto && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function inEditable(doc) {
  const active = doc.activeElement;
  return Boolean(active && (EDITABLE.has(active.tagName) || active.isContentEditable));
}

function headingText(content, id) {
  if (!id) {
    return "";
  }
  const heading = content.ownerDocument.getElementById(id);
  return heading && content.contains(heading) ? heading.textContent.trim() : id;
}

function scrollRangeIntoView(range, win) {
  const element = range.startContainer.nodeType === 3 ? range.startContainer.parentElement : range.startContainer;
  if (element && typeof element.scrollIntoView === "function") {
    element.scrollIntoView({ block: "center" });
  }
  const selection = win.getSelection && win.getSelection();
  if (selection) {
    selection.removeAllRanges();
    selection.addRange(range);
  }
}

/**
 * The "Save for later" button.
 * @param {HTMLButtonElement} button
 * @param {Object} store
 * @returns {{refresh: Function}}
 */
export function initBookmark(button, store) {
  const article = button.dataset.article;
  const title = button.dataset.title || "";
  const label = button.querySelector("[data-bookmark-label]") || button;

  const render = () => {
    const record = store.read(article);
    const saved = Boolean(record && record.bookmarked);
    button.setAttribute("aria-pressed", saved ? "true" : "false");
    label.textContent = saved ? button.dataset.labelSaved : button.dataset.labelSave;
  };

  if (!store.available) {
    button.disabled = true;
    button.title = button.dataset.unavailable || "";
    return { refresh: render };
  }

  button.addEventListener("click", () => {
    const record = store.read(article) || emptyRecord(article, title);
    record.title = record.title || title;
    record.bookmarked = !record.bookmarked;
    record.saved_at = record.bookmarked ? new Date().toISOString() : undefined;
    store.write(article, record);
    render();
  });
  render();
  return { refresh: render };
}

/**
 * The export, import and erase controls shared by the panel and the list.
 * @param {Element} root
 * @param {Object} store
 * @param {Function} onChange - Called after an import or an erase
 * @param {string} [article] - The article an "erase this article" button removes
 */
export function initDataControls(root, store, onChange, article) {
  const doc = root.ownerDocument;
  const win = doc.defaultView;
  const status = root.querySelector("[data-reading-status]");
  const say = (text) => {
    if (status) {
      status.textContent = text;
    }
  };

  const exportButton = root.querySelector("[data-reading-export]");
  if (exportButton) {
    exportButton.addEventListener("click", () => {
      const blob = new win.Blob([store.exportJSON()], { type: "application/json" });
      const url = win.URL.createObjectURL(blob);
      const link = doc.createElement("a");
      link.href = url;
      link.download = "datalog-reading-data.json";
      doc.body.appendChild(link);
      link.click();
      link.remove();
      win.URL.revokeObjectURL(url);
      say(exportButton.dataset.done || "");
    });
  }

  const importInput = root.querySelector("[data-reading-import]");
  if (importInput) {
    importInput.addEventListener("change", () => {
      const file = importInput.files && importInput.files[0];
      if (!file) {
        return;
      }
      file
        .text()
        .then((text) => {
          const count = store.importJSON(text);
          say(fill(importInput.dataset.done, { count }));
          onChange();
        })
        .catch(() => say(importInput.dataset.failed || ""));
      importInput.value = "";
    });
  }

  const eraseArticle = root.querySelector("[data-reading-erase-article]");
  if (eraseArticle && article) {
    eraseArticle.addEventListener("click", () => {
      store.remove(article);
      say(eraseArticle.dataset.done || "");
      onChange();
    });
  }

  const eraseAll = root.querySelector("[data-reading-erase-all]");
  if (eraseAll) {
    eraseAll.addEventListener("click", () => {
      if (eraseAll.dataset.confirm && !win.confirm(eraseAll.dataset.confirm)) {
        return;
      }
      store.clear();
      say(eraseAll.dataset.done || "");
      onChange();
    });
  }
}

/**
 * A post's reading state: progress, the resume prompt, highlights and notes.
 * @param {Element} root - The element carrying data-reading-state
 * @param {Object} store
 * @param {Object} [options]
 * @param {Element} [options.content] - The article body; defaults to .post-content
 * @param {HTMLButtonElement} [options.bookmark]
 * @returns {Object} The controller, for tests: addAnnotation, removeAnnotation, record, repaint
 */
export function initArticle(root, store, options = {}) {
  const doc = root.ownerDocument;
  const win = doc.defaultView;
  const article = root.dataset.article;
  const title = root.dataset.title || "";
  const content = options.content || doc.querySelector(".post-content");
  const wantProgress = root.dataset.progress !== "false";
  const wantHighlights = root.dataset.highlights !== "false";
  const resume = root.querySelector("[data-reading-resume]");
  const toolbar = root.querySelector("[data-reading-toolbar]");
  const list = root.querySelector("[data-reading-list-items]");
  const empty = root.querySelector("[data-reading-empty]");
  const template = root.querySelector("[data-reading-item-template]");
  const unavailable = root.querySelector("[data-reading-unavailable]");
  const bookmark = options.bookmark ? initBookmark(options.bookmark, store) : null;
  let pendingRange = null;
  let lostIds = [];

  const record = () => store.read(article) || emptyRecord(article, title);
  const save = (next) => {
    next.title = next.title || title;
    store.write(article, next);
  };

  if (!store.available) {
    if (unavailable) {
      unavailable.hidden = false;
    }
    root.querySelectorAll("button, input").forEach((control) => {
      control.disabled = true;
    });
    return { available: false, record, addAnnotation: () => null, removeAnnotation: () => false, repaint: () => null };
  }

  const repaint = () => {
    if (!content || !wantHighlights) {
      return { found: [], lost: [] };
    }
    const painted = paint(content, record().annotations);
    lostIds = painted.lost;
    return painted;
  };

  const renderList = () => {
    if (!list || !template) {
      return;
    }
    const annotations = record().annotations;
    list.textContent = "";
    if (empty) {
      empty.hidden = annotations.length > 0;
    }
    annotations.forEach((annotation) => {
      const item = template.content.firstElementChild.cloneNode(true);
      item.dataset.annotation = annotation.id;
      const quote = item.querySelector("[data-annotation-quote]");
      quote.textContent = annotation.quote.length > 160 ? `${annotation.quote.slice(0, 157)}…` : annotation.quote;
      const section = item.querySelector("[data-annotation-section]");
      section.textContent = headingText(content, annotation.section);
      const lost = item.querySelector("[data-annotation-lost]");
      lost.hidden = !lostIds.includes(annotation.id);
      const note = item.querySelector("[data-annotation-note]");
      note.value = annotation.note || "";
      note.addEventListener("change", () => {
        const next = record();
        const target = next.annotations.find((candidate) => candidate.id === annotation.id);
        if (target) {
          target.note = note.value;
          save(next);
        }
      });
      item.querySelector("[data-annotation-go]").addEventListener("click", () => {
        const range = content && locate(content, annotation);
        if (range) {
          scrollRangeIntoView(range, win);
        }
      });
      item.querySelector("[data-annotation-remove]").addEventListener("click", () => {
        controller.removeAnnotation(annotation.id);
      });
      list.appendChild(item);
    });
  };

  const refresh = () => {
    repaint();
    renderList();
    if (bookmark) {
      bookmark.refresh();
    }
  };

  const hideToolbar = () => {
    if (toolbar) {
      toolbar.hidden = true;
    }
  };

  const showToolbar = (range) => {
    if (!toolbar) {
      return;
    }
    pendingRange = range;
    toolbar.hidden = false;
    if (typeof range.getBoundingClientRect === "function") {
      const rect = range.getBoundingClientRect();
      toolbar.style.top = `${Math.max(0, rect.top + win.scrollY - toolbar.offsetHeight - 8)}px`;
      toolbar.style.left = `${Math.max(0, rect.left + win.scrollX)}px`;
    }
  };

  const currentRange = () => {
    const selection = win.getSelection && win.getSelection();
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed || !content) {
      return null;
    }
    const range = selection.getRangeAt(0);
    return content.contains(range.commonAncestorContainer) ? range : null;
  };

  const controller = {
    available: true,
    record,
    repaint,
    /**
     * Saves a highlight of a range, with a note when given.
     * @param {Range} range
     * @param {string} [note]
     * @returns {Object|null} The annotation, or null when the range holds no text
     */
    addAnnotation(range, note = "") {
      if (!content) {
        return null;
      }
      const anchor = describeRange(range, content);
      if (!anchor || anchor.quote.trim() === "") {
        return null;
      }
      const annotation = { id: newId(), ...anchor, note, created_at: new Date().toISOString() };
      const next = record();
      next.annotations.push(annotation);
      save(next);
      refresh();
      return annotation;
    },
    removeAnnotation(id) {
      const next = record();
      const before = next.annotations.length;
      next.annotations = next.annotations.filter((annotation) => annotation.id !== id);
      if (next.annotations.length === before) {
        return false;
      }
      save(next);
      refresh();
      return true;
    },
    /** Highlights the current selection; with `withNote`, focuses its note. */
    highlightSelection(withNote = false) {
      const range = pendingRange || currentRange();
      if (!range) {
        return null;
      }
      const annotation = controller.addAnnotation(range);
      pendingRange = null;
      hideToolbar();
      const selection = win.getSelection && win.getSelection();
      if (selection) {
        selection.removeAllRanges();
      }
      if (annotation && withNote && list) {
        const item = list.querySelector(`[data-annotation="${annotation.id}"] [data-annotation-note]`);
        if (item) {
          item.focus();
        }
      }
      return annotation;
    }
  };

  if (wantHighlights && toolbar && content) {
    let timer = null;
    doc.addEventListener("selectionchange", () => {
      if (timer) {
        win.clearTimeout(timer);
      }
      timer = win.setTimeout(() => {
        const range = currentRange();
        if (range) {
          showToolbar(range.cloneRange());
        } else if (!toolbar.contains(doc.activeElement)) {
          pendingRange = null;
          hideToolbar();
        }
      }, 150);
    });
    const highlightButton = toolbar.querySelector("[data-reading-highlight]");
    const noteButton = toolbar.querySelector("[data-reading-note]");
    if (highlightButton) {
      highlightButton.addEventListener("click", () => controller.highlightSelection(false));
    }
    if (noteButton) {
      noteButton.addEventListener("click", () => controller.highlightSelection(true));
    }
    doc.addEventListener("keydown", (event) => {
      if (!event.altKey || !event.shiftKey || inEditable(doc)) {
        return;
      }
      const key = event.key.toLowerCase();
      if (key === "h" || key === "n") {
        event.preventDefault();
        controller.highlightSelection(key === "n");
      }
    });
  }

  if (wantProgress && content) {
    const saved = record().progress;
    if (resume && !win.location.hash && worthResuming(saved, content.getBoundingClientRect().height, win.innerHeight)) {
      const detail = resume.querySelector("[data-reading-resume-detail]");
      if (detail) {
        const section = headingText(content, saved.anchor);
        const percent = Math.round(saved.ratio * 100);
        detail.textContent = `${section ? `${section} · ` : ""}${fill(resume.dataset.progressLabel, { percent })}`;
      }
      resume.hidden = false;
      const go = resume.querySelector("[data-reading-resume-go]");
      if (go) {
        go.addEventListener("click", () => {
          const heading = saved.anchor && doc.getElementById(saved.anchor);
          if (heading && typeof heading.scrollIntoView === "function") {
            heading.scrollIntoView({ block: "start" });
          } else {
            const rect = content.getBoundingClientRect();
            win.scrollTo(0, rect.top + win.scrollY + rect.height * saved.ratio - win.innerHeight * 0.4);
          }
          resume.hidden = true;
        });
      }
      const dismiss = resume.querySelector("[data-reading-resume-dismiss]");
      if (dismiss) {
        dismiss.addEventListener("click", () => {
          resume.hidden = true;
        });
      }
    }
    trackProgress({ content, store, article, title, win });
  }

  initDataControls(root, store, refresh, article);
  refresh();
  return controller;
}

/**
 * The list of saved articles on a page, with their progress and highlights.
 * @param {Element} root - The element carrying data-reading-list
 * @param {Object} store
 * @returns {{render: Function}}
 */
export function initReadingList(root, store) {
  const doc = root.ownerDocument;
  const list = root.querySelector("[data-reading-list-items]");
  const empty = root.querySelector("[data-reading-list-empty]");
  const unavailable = root.querySelector("[data-reading-unavailable]");

  const render = () => {
    if (!list) {
      return;
    }
    const records = store
      .all()
      .filter((record) => record.bookmarked || record.progress || record.annotations.length > 0)
      .sort((a, b) => String(b.updated_at || "").localeCompare(String(a.updated_at || "")));
    list.textContent = "";
    if (empty) {
      empty.hidden = records.length > 0;
    }
    records.forEach((record) => {
      const item = doc.createElement("li");
      item.className = "reading-list__item";
      const link = doc.createElement("a");
      link.href = record.article;
      link.textContent = record.title || record.article;
      item.appendChild(link);
      const meta = doc.createElement("span");
      meta.className = "reading-list__meta";
      const parts = [];
      if (record.bookmarked) {
        parts.push(root.dataset.savedLabel || "");
      }
      if (record.progress) {
        parts.push(fill(root.dataset.progressLabel, { percent: Math.round(record.progress.ratio * 100) }));
      }
      if (record.annotations.length > 0) {
        parts.push(fill(root.dataset.highlightsLabel, { count: record.annotations.length }));
      }
      meta.textContent = parts.filter(Boolean).join(" · ");
      item.appendChild(meta);
      const remove = doc.createElement("button");
      remove.type = "button";
      remove.className = "post-tool";
      remove.textContent = root.dataset.removeLabel || "";
      remove.addEventListener("click", () => {
        store.remove(record.article);
        render();
      });
      item.appendChild(remove);
      list.appendChild(item);
    });
  };

  if (!store.available) {
    if (unavailable) {
      unavailable.hidden = false;
    }
    root.querySelectorAll("button, input").forEach((control) => {
      control.disabled = true;
    });
    return { render };
  }

  initDataControls(root, store, render);
  render();
  return { render };
}

/**
 * Wires every reading-state element on the page.
 * @param {Document} [doc]
 * @param {Object} [store]
 * @returns {{article: Object|null, list: Object|null}}
 */
export function initReadingState(doc = document, store = createStore()) {
  const articleRoot = doc.querySelector("[data-reading-state]");
  const listRoot = doc.querySelector("[data-reading-list]");
  const bookmark = doc.querySelector("[data-bookmark-toggle]");
  const result = { article: null, list: null };
  if (articleRoot) {
    result.article = initArticle(articleRoot, store, { bookmark });
  } else if (bookmark) {
    initBookmark(bookmark, store);
  }
  if (listRoot) {
    result.list = initReadingList(listRoot, store);
  }
  return result;
}
