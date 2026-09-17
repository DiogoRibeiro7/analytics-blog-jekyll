/**
 * @fileoverview Reading progress (#260): where a reader is in a long article,
 * as a ratio of the article and the nearest heading, saved as they scroll and
 * offered back when they return.
 * @module reading-state/progress
 */

import { emptyRecord } from "./storage.js";

/** The point of the window, from its top, taken as where the reader is. */
export const READING_LINE = 0.4;

/**
 * @param {Object} view
 * @param {number} view.scrollY
 * @param {number} view.innerHeight
 * @param {number} view.contentTop - The article's top, from the document's top
 * @param {number} view.contentHeight
 * @param {Array<{id: string, top: number}>} view.headings - The article's headings, from the document's top
 * @returns {{ratio: number, anchor: string|null}}
 */
export function measure({ scrollY, innerHeight, contentTop, contentHeight, headings }) {
  const line = scrollY + innerHeight * READING_LINE;
  const ratio = contentHeight > 0 ? Math.min(1, Math.max(0, (line - contentTop) / contentHeight)) : 0;
  let anchor = null;
  headings.forEach((heading) => {
    if (heading.top <= line) {
      anchor = heading.id;
    }
  });
  return { ratio: Math.round(ratio * 1000) / 1000, anchor };
}

/**
 * Whether a saved position is worth offering back: some way in, not at the
 * end, and in an article longer than the window.
 * @param {Object|undefined} progress
 * @param {number} contentHeight
 * @param {number} innerHeight
 * @returns {boolean}
 */
export function worthResuming(progress, contentHeight, innerHeight) {
  return Boolean(
    progress &&
      typeof progress.ratio === "number" &&
      progress.ratio >= 0.05 &&
      progress.ratio <= 0.92 &&
      contentHeight > innerHeight * 1.5
  );
}

/**
 * Saves the reader's position a moment after they stop scrolling.
 * @param {Object} options
 * @param {Element} options.content - The article body
 * @param {Object} options.store
 * @param {string} options.article
 * @param {string} options.title
 * @param {Window} [options.win]
 * @param {number} [options.interval] - Milliseconds of quiet before a save
 * @returns {{stop: Function, save: Function, snapshot: Function}}
 */
export function trackProgress({ content, store, article, title, win = window, interval = 1000 }) {
  let timer = null;
  let last = null;

  const snapshot = () => {
    const rect = content.getBoundingClientRect();
    const headings = Array.from(content.querySelectorAll("h2[id], h3[id], h4[id]")).map((heading) => ({
      id: heading.id,
      top: heading.getBoundingClientRect().top + win.scrollY
    }));
    return measure({
      scrollY: win.scrollY,
      innerHeight: win.innerHeight,
      contentTop: rect.top + win.scrollY,
      contentHeight: rect.height,
      headings
    });
  };

  const save = () => {
    const progress = snapshot();
    if (last && Math.abs(last.ratio - progress.ratio) < 0.01) {
      return;
    }
    last = progress;
    const record = store.read(article) || emptyRecord(article, title);
    record.title = record.title || title;
    record.progress = { ...progress, updated_at: new Date().toISOString() };
    store.write(article, record);
  };

  const onScroll = () => {
    if (timer) {
      return;
    }
    timer = win.setTimeout(() => {
      timer = null;
      save();
    }, interval);
  };

  win.addEventListener("scroll", onScroll, { passive: true });
  return {
    stop() {
      win.removeEventListener("scroll", onScroll);
      if (timer) {
        win.clearTimeout(timer);
      }
    },
    save,
    snapshot
  };
}
