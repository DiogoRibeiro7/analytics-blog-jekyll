/**
 * @fileoverview Text anchors for private highlights (#260). A highlight is
 * saved as the quoted text with a little of what comes before and after it,
 * the way a text quote selector does, rather than as DOM offsets, so it is
 * found again after the article is edited as long as the passage survives.
 * @module reading-state/anchors
 */

export const CONTEXT = 32;

const SKIP = new Set(["SCRIPT", "STYLE", "TEMPLATE", "NOSCRIPT"]);
const TEXT_NODE = 3;

/**
 * The text of a root's text nodes in document order, with where each starts.
 * @param {Element} root
 * @returns {{text: string, nodes: Array<{node: Text, start: number, end: number}>}}
 */
export function textIndex(root) {
  const doc = root.ownerDocument;
  const nodes = [];
  let text = "";
  const walker = doc.createTreeWalker(root, 4 /* NodeFilter.SHOW_TEXT */, {
    acceptNode(node) {
      return SKIP.has(node.parentNode && node.parentNode.nodeName) ? 2 /* REJECT */ : 1; /* ACCEPT */
    }
  });
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    nodes.push({ node, start: text.length, end: text.length + node.data.length });
    text += node.data;
  }
  return { text, nodes };
}

function follows(reference, node) {
  return Boolean(reference.compareDocumentPosition(node) & 4 /* DOCUMENT_POSITION_FOLLOWING */);
}

/** The position in the index's text of a boundary point of a range. */
function positionOf(index, container, offset) {
  if (container.nodeType === TEXT_NODE) {
    const entry = index.nodes.find((candidate) => candidate.node === container);
    return entry ? entry.start + offset : 0;
  }
  const child = container.childNodes[offset];
  if (!child) {
    const after = index.nodes.find((entry) => !container.contains(entry.node) && follows(container, entry.node));
    return after ? after.start : index.text.length;
  }
  const entry = index.nodes.find(
    (candidate) => candidate.node === child || child.contains(candidate.node) || follows(child, candidate.node)
  );
  return entry ? entry.start : index.text.length;
}

/**
 * The id of the last heading before a node, so a highlight can say which
 * section it belongs to.
 * @param {Element} root
 * @param {Node} node
 * @returns {string|null}
 */
export function sectionOf(root, node) {
  const element = node.nodeType === TEXT_NODE ? node.parentNode : node;
  let section = null;
  root.querySelectorAll("h2[id], h3[id], h4[id]").forEach((heading) => {
    if (heading === element || heading.contains(element) || follows(heading, element)) {
      section = heading.id;
    }
  });
  return section;
}

/**
 * Describes a range as a quote with its context.
 * @param {Range} range
 * @param {Element} root
 * @returns {{quote: string, prefix: string, suffix: string, section: string|null}|null}
 */
export function describeRange(range, root) {
  const index = textIndex(root);
  const start = positionOf(index, range.startContainer, range.startOffset);
  const end = positionOf(index, range.endContainer, range.endOffset);
  if (end <= start) {
    return null;
  }
  return {
    quote: index.text.slice(start, end),
    prefix: index.text.slice(Math.max(0, start - CONTEXT), start),
    suffix: index.text.slice(end, end + CONTEXT),
    section: sectionOf(root, range.startContainer)
  };
}

function occurrences(text, quote) {
  const found = [];
  let at = text.indexOf(quote);
  while (at !== -1) {
    found.push(at);
    at = text.indexOf(quote, at + 1);
  }
  return found;
}

/** Collapses runs of whitespace, keeping where each kept character came from. */
function normalize(text) {
  let out = "";
  const map = [];
  let space = false;
  for (let at = 0; at < text.length; at += 1) {
    const char = text[at];
    if (/\s/.test(char)) {
      if (!space) {
        out += " ";
        map.push(at);
        space = true;
      }
    } else {
      out += char;
      map.push(at);
      space = false;
    }
  }
  return { out, map };
}

function overlapEnd(a, b) {
  let count = 0;
  while (count < a.length && count < b.length && a[a.length - 1 - count] === b[b.length - 1 - count]) {
    count += 1;
  }
  return count;
}

function overlapStart(a, b) {
  let count = 0;
  while (count < a.length && count < b.length && a[count] === b[count]) {
    count += 1;
  }
  return count;
}

/**
 * A range over a slice of the index's text.
 * @param {{text: string, nodes: Array}} index
 * @param {number} start
 * @param {number} end
 * @returns {Range|null}
 */
export function rangeOf(index, start, end) {
  const startEntry =
    index.nodes.find((entry) => start >= entry.start && start < entry.end) ||
    index.nodes.find((entry) => start === entry.end);
  const endEntry = index.nodes.find((entry) => end > entry.start && end <= entry.end);
  if (!startEntry || !endEntry) {
    return null;
  }
  const range = startEntry.node.ownerDocument.createRange();
  range.setStart(startEntry.node, start - startEntry.start);
  range.setEnd(endEntry.node, end - endEntry.start);
  return range;
}

/**
 * Finds a saved quote in the root's current text: the exact text first, then
 * the same words with any whitespace; among several matches, the one whose
 * surroundings agree most with the saved prefix and suffix.
 * @param {Element} root
 * @param {{quote: string, prefix?: string, suffix?: string}} anchor
 * @returns {Range|null} Null when the passage is gone
 */
export function locate(root, anchor) {
  if (!anchor || typeof anchor.quote !== "string" || anchor.quote === "") {
    return null;
  }
  const index = textIndex(root);
  let candidates = occurrences(index.text, anchor.quote).map((start) => ({ start, end: start + anchor.quote.length }));
  if (candidates.length === 0) {
    const normalized = normalize(index.text);
    const quote = normalize(anchor.quote).out.trim();
    if (quote) {
      candidates = occurrences(normalized.out, quote).map((start) => ({
        start: normalized.map[start],
        end: normalized.map[start + quote.length - 1] + 1
      }));
    }
  }
  if (candidates.length === 0) {
    return null;
  }
  let scored = candidates.map((candidate) => ({
    ...candidate,
    section: sectionOf(root, rangeOf(index, candidate.start, candidate.end).startContainer),
    score:
      overlapEnd(index.text.slice(Math.max(0, candidate.start - CONTEXT), candidate.start), anchor.prefix || "") +
      overlapStart(index.text.slice(candidate.end, candidate.end + CONTEXT), anchor.suffix || "")
  }));
  if (anchor.section) {
    const inSection = scored.filter((candidate) => candidate.section === anchor.section);
    if (inSection.length) scored = inSection;
    else return null;
  }
  scored.sort((a, b) => b.score - a.score);
  if (scored.length > 1 && (scored[0].score === 0 || scored[0].score === scored[1].score)) return null;
  if (!anchor.section && (anchor.prefix || anchor.suffix) && scored[0].score === 0) return null;
  return rangeOf(index, scored[0].start, scored[0].end);
}
