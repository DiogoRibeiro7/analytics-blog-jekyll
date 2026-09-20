/**
 * @fileoverview Local reading state (#260): bookmarks, reading progress and
 * private highlights, kept in this browser under one localStorage key per
 * article. No account, no backend, no telemetry: what a reader saves stays
 * on their device, and they can export, import or erase it.
 * @module reading-state/storage
 */

export const PREFIX = "datalog-reading:";
export const FORMAT = 1;

/**
 * localStorage when the browser lets this site use it, else null: a private
 * window or blocked site data answers null. Full storage remains readable
 * so readers can export or erase data to make room.
 * @param {Window} [win]
 * @returns {Storage|null}
 */
export function browserStorage(win = window) {
  try {
    const storage = win.localStorage;
    const key = `${PREFIX}probe`;
    storage.setItem(key, "1");
    storage.removeItem(key);
    return storage;
  } catch (error) {
    if (error.name === "QuotaExceededError" || error.code === 22) {
      try {
        win.localStorage.getItem(`${PREFIX}probe`);
        return win.localStorage;
      } catch (_blocked) {
        return null;
      }
    }
    return null;
  }
}

/**
 * @param {string} article - The article's URL on the site
 * @param {string} [title]
 * @returns {Object} A record with nothing saved yet
 */
export function emptyRecord(article, title = "") {
  return { article, title, bookmarked: false, annotations: [] };
}

/**
 * @param {*} annotation
 * @returns {boolean} Whether it has what a highlight needs to be found again
 */
export function validAnnotation(annotation) {
  return Boolean(
    annotation && typeof annotation.id === "string" && typeof annotation.quote === "string" && annotation.quote.length > 0
  );
}

function parse(text) {
  try {
    const value = JSON.parse(text);
    return value && typeof value === "object" ? value : null;
  } catch (error) {
    return null;
  }
}

/**
 * A record as an import or an old browser may hold it, reduced to the fields
 * the theme reads.
 * @param {Object} record
 * @returns {Object|null}
 */
export function cleanRecord(record) {
  if (!record || typeof record.article !== "string" || record.article === "") {
    return null;
  }
  const clean = emptyRecord(record.article, typeof record.title === "string" ? record.title : "");
  clean.bookmarked = record.bookmarked === true;
  const annotations = new Map();
  (Array.isArray(record.annotations) ? record.annotations : []).filter(validAnnotation).forEach((annotation) => {
    const saved = { id: annotation.id, quote: annotation.quote };
    ["prefix", "suffix", "section", "note", "created_at"].forEach((field) => {
      if (typeof annotation[field] === "string") saved[field] = annotation[field];
    });
    annotations.set(saved.id, saved);
  });
  clean.annotations = [...annotations.values()];
  if (record.progress && Number.isFinite(record.progress.ratio)) {
    clean.progress = {
      ratio: Math.min(1, Math.max(0, record.progress.ratio)),
      anchor: typeof record.progress.anchor === "string" ? record.progress.anchor : null
    };
    if (typeof record.progress.updated_at === "string") clean.progress.updated_at = record.progress.updated_at;
  }
  if (typeof record.saved_at === "string") {
    clean.saved_at = record.saved_at;
  }
  if (typeof record.updated_at === "string") {
    clean.updated_at = record.updated_at;
  }
  return clean;
}

/**
 * The store: one record per article, all of them behind the same prefix so
 * they can be listed, exported and erased together.
 * @param {Storage|null} [storage] - Defaults to the browser's localStorage when available
 * @returns {Object} The store, with `available` saying whether anything is saved at all
 */
export function createStore(storage = browserStorage()) {
  const available = Boolean(storage);
  const keyOf = (article) => `${PREFIX}${article}`;

  function keys() {
    const found = [];
    for (let index = 0; index < storage.length; index += 1) {
      const key = storage.key(index);
      if (key && key.startsWith(PREFIX) && key !== `${PREFIX}probe`) {
        found.push(key);
      }
    }
    return found;
  }

  function read(article) {
    if (!available) {
      return null;
    }
    try {
      return cleanRecord(parse(storage.getItem(keyOf(article))));
    } catch (error) {
      return null;
    }
  }

  function write(article, record) {
    if (!available) {
      return false;
    }
    try {
      const clean = cleanRecord({ ...record, article });
      if (!clean) {
        return false;
      }
      clean.updated_at = new Date().toISOString();
      storage.setItem(keyOf(article), JSON.stringify(clean));
      return true;
    } catch (error) {
      return false;
    }
  }

  function remove(article) {
    if (!available) {
      return false;
    }
    try {
      storage.removeItem(keyOf(article));
      return true;
    } catch (error) {
      return false;
    }
  }

  function all() {
    if (!available) {
      return [];
    }
    try {
      return keys()
        .map((key) => cleanRecord(parse(storage.getItem(key))))
        .filter(Boolean);
    } catch (error) {
      return [];
    }
  }

  function clear() {
    if (!available) {
      return false;
    }
    try {
      keys().forEach((key) => storage.removeItem(key));
      return true;
    } catch (error) {
      return false;
    }
  }

  function exportJSON() {
    return JSON.stringify({ format: FORMAT, exported_at: new Date().toISOString(), articles: all() }, null, 2);
  }

  /**
   * Merges an export with existing bookmarks and annotations by article/id.
   * @param {string} text
   * @returns {number} How many articles were written
   */
  function importJSON(text) {
    const data = parse(text);
    const articles = Array.isArray(data) ? data : data && Array.isArray(data.articles) ? data.articles : null;
    if (!articles) {
      throw new Error("Not a reading data export");
    }
    return articles.reduce((count, record) => {
      const clean = cleanRecord(record);
      if (!clean) return count;
      const existing = read(clean.article);
      if (existing) {
        clean.annotations = [...new Map([...existing.annotations, ...clean.annotations].map((item) => [item.id, item])).values()];
        clean.bookmarked = clean.bookmarked || existing.bookmarked;
        clean.title = clean.title || existing.title;
        clean.saved_at = clean.saved_at || existing.saved_at;
        if (!clean.progress || (Date.parse(existing.progress?.updated_at) || 0) > (Date.parse(clean.progress.updated_at) || 0)) {
          clean.progress = existing.progress;
        }
      }
      if (!write(clean.article, clean)) throw new Error("Reading data could not be saved");
      return count + 1;
    }, 0);
  }

  return { available, read, write, remove, all, clear, exportJSON, importJSON };
}
