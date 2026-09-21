/**
 * @fileoverview The article's table of contents: which section the reader is
 * in, how far through the article they are, and whether the panel is open.
 *
 * Reaching a heading is not this module's job. The entries are ordinary
 * fragment links, and the browser follows them: it scrolls, it moves focus to
 * the heading, it updates the address bar, and `scroll-margin-top` on the
 * headings (_sass/_typography.scss) keeps the sticky header off them. The
 * script this replaced cancelled that and did it by hand, which broke every
 * link to a heading whose id starts with a digit — "1. Introduction" and the
 * rest — because `#1-introduction` is not a valid selector and the call threw
 * after the default had already been prevented (#330).
 * @module core/toc
 */

const ACTIVE = "is-active";
const HEADING_SELECTOR = ".post-content h2[id], .post-content h3[id], .post-content h4[id]";
/** Where a heading sits when nothing says otherwise, and how far past it the section starts. */
const FALLBACK_READING_LINE = 100;
const PAST_THE_HEADING = 8;
/** How far past the contents the reader scrolls before it sticks. */
const STICKY_MARGIN = 20;

/**
 * The heading the reader is in: the last one at or above the reading line.
 * Positions come from the viewport, so a positioned ancestor cannot throw
 * this off the way `offsetTop` could.
 * @param {Element[]} headings - The article's headings, in document order
 * @param {number} [line] - Distance below the top of the viewport
 * @returns {Element|null}
 */
export function currentHeading(headings, line = FALLBACK_READING_LINE) {
  let current = null;
  headings.forEach((heading) => {
    if (heading.getBoundingClientRect().top <= line) {
      current = heading;
    }
  });
  return current;
}

/**
 * How far through the article the reader is, as a whole percent. An article
 * shorter than the viewport has nothing to scroll: that is 0, not the NaN a
 * division by an empty track produced.
 * @param {number} scrollTop
 * @param {number} viewportHeight
 * @param {number} documentHeight
 * @returns {number} 0 to 100
 */
export function scrolledPercent(scrollTop, viewportHeight, documentHeight) {
  const track = documentHeight - viewportHeight;
  if (track <= 0) {
    return 0;
  }
  return Math.min(100, Math.max(0, Math.floor((scrollTop / track) * 100)));
}

/**
 * Wires one table of contents.
 * @param {Element} toc - The element carrying data-toc-enhanced
 * @param {Object} [deps] - `window`, replaceable in tests
 * @returns {Object|null} The controller, for tests
 */
export function initTocPanel(toc, deps = {}) {
  const doc = toc.ownerDocument;
  const win = deps.window || doc.defaultView;
  const links = Array.from(toc.querySelectorAll(".enhanced-toc__content a"));
  const toggle = toc.querySelector("[data-toc-toggle]");
  const content = toc.querySelector(".enhanced-toc__content");
  const progressBar = toc.querySelector("[data-toc-progress]");
  const progressPercent = toc.querySelector("[data-progress-percent]");
  const headings = Array.from(doc.querySelectorAll(HEADING_SELECTOR));
  // The contents move when they stick, so the threshold is measured against
  // the column they sit in, which does not.
  const anchor = toc.parentElement || toc;
  let shownPercent = null;

  if (toggle && content) {
    toggle.addEventListener("click", () => {
      const expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", expanded ? "false" : "true");
      content.hidden = expanded;
      toc.classList.toggle("is-collapsed", expanded);
    });
  }

  // A heading the browser has just jumped to comes to rest at its own
  // scroll-margin-top, clear of the sticky header. The reader is in that
  // section from then on, so the line that decides sits just below it.
  const readingLine = () => {
    if (headings.length === 0) {
      return FALLBACK_READING_LINE;
    }
    const margin = parseFloat(win.getComputedStyle(headings[0]).scrollMarginTop);
    return (Number.isFinite(margin) ? margin : FALLBACK_READING_LINE) + PAST_THE_HEADING;
  };

  const showCurrentSection = () => {
    const heading = currentHeading(headings, readingLine());
    const target = heading ? `#${heading.id}` : null;
    links.forEach((link) => {
      const active = target !== null && link.getAttribute("href") === target;
      link.classList.toggle(ACTIVE, active);
      if (active) {
        link.setAttribute("aria-current", "location");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  };

  const showProgress = () => {
    const percent = scrolledPercent(win.scrollY, win.innerHeight, doc.documentElement.scrollHeight);
    if (percent === shownPercent) {
      return;
    }
    shownPercent = percent;
    if (progressBar) {
      progressBar.style.width = `${percent}%`;
    }
    if (progressPercent) {
      progressPercent.textContent = String(percent);
    }
  };

  const showSticky = () => {
    const top = anchor.getBoundingClientRect().top + win.scrollY;
    toc.classList.toggle("is-sticky", win.scrollY > top - STICKY_MARGIN);
  };

  const update = () => {
    showCurrentSection();
    showProgress();
    showSticky();
  };

  let frame = null;
  const onScroll = () => {
    if (frame !== null) {
      win.cancelAnimationFrame(frame);
    }
    frame = win.requestAnimationFrame(() => {
      frame = null;
      update();
    });
  };

  if (headings.length > 0) {
    win.addEventListener("scroll", onScroll, { passive: true });
    win.addEventListener("resize", onScroll, { passive: true });
    update();
  }

  return { toc, update, headings, links };
}

/**
 * Wires every table of contents on the page.
 * @param {Document} [doc]
 * @returns {Object[]}
 */
export function initToc(doc = document) {
  return Array.from(doc.querySelectorAll("[data-toc-enhanced]")).map((toc) => initTocPanel(toc));
}
