/**
 * @fileoverview Painting private highlights (#260): with the CSS Custom
 * Highlight API where the browser has it, which touches no DOM and so never
 * gets in the way of selecting or copying, and by wrapping the text in
 * <mark> elements elsewhere.
 * @module reading-state/highlights
 */

import { locate } from "./anchors.js";

export const HIGHLIGHT_NAME = "datalog-annotation";
export const MARK_CLASS = "reading-highlight";

/**
 * @param {Window} [win]
 * @returns {boolean} Whether CSS.highlights and Highlight exist
 */
export function supportsHighlightAPI(win = window) {
  return Boolean(win && win.CSS && "highlights" in win.CSS && typeof win.Highlight === "function");
}

/**
 * Removes every mark the fallback wrote, joining the text back together.
 * @param {Element} root
 */
export function clearMarks(root) {
  root.querySelectorAll(`mark.${MARK_CLASS}`).forEach((mark) => {
    const parent = mark.parentNode;
    while (mark.firstChild) {
      parent.insertBefore(mark.firstChild, mark);
    }
    parent.removeChild(mark);
    parent.normalize();
  });
}

/**
 * Wraps the text a range covers, one <mark> per text node, so a highlight
 * that crosses elements still wraps only text.
 * @param {Range} range
 * @param {string} id
 */
export function wrapRange(range, id) {
  const doc = range.startContainer.ownerDocument;
  const common = range.commonAncestorContainer;
  const nodes = [];
  if (common.nodeType === 3) {
    nodes.push(common);
  } else {
    const walker = doc.createTreeWalker(common, 4 /* NodeFilter.SHOW_TEXT */);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (range.intersectsNode(node)) {
        nodes.push(node);
      }
    }
  }
  nodes.forEach((node) => {
    if (!node.data.trim() || node.parentElement?.namespaceURI !== "http://www.w3.org/1999/xhtml") return;
    const piece = doc.createRange();
    piece.setStart(node, node === range.startContainer ? range.startOffset : 0);
    piece.setEnd(node, node === range.endContainer ? range.endOffset : node.data.length);
    if (piece.collapsed) {
      return;
    }
    const mark = doc.createElement("mark");
    mark.className = MARK_CLASS;
    mark.dataset.annotationId = id;
    piece.surroundContents(mark);
  });
}

/**
 * Paints every annotation whose passage can still be found.
 * @param {Element} root
 * @param {Array<Object>} annotations
 * @param {{api?: boolean}} [options] - Force the API or the fallback, for tests
 * @returns {{found: string[], lost: string[]}} The ids found and the ids whose passage is gone
 */
export function paint(root, annotations, options = {}) {
  const win = root.ownerDocument.defaultView;
  const api = options.api === undefined ? supportsHighlightAPI(win) : options.api;
  const found = [];
  const lost = [];
  clearMarks(root);
  const ranges = [];
  annotations.forEach((annotation) => {
    const range = locate(root, annotation);
    if (range) {
      found.push(annotation.id);
      ranges.push([annotation.id, range]);
    } else {
      lost.push(annotation.id);
    }
  });
  if (api) {
    win.CSS.highlights.set(HIGHLIGHT_NAME, new win.Highlight(...ranges.map(([, range]) => range)));
  } else {
    // Later text first, so the earlier ranges' offsets still hold as nodes split.
    ranges.reverse().forEach(([id, range]) => wrapRange(range, id));
  }
  return { found, lost };
}
