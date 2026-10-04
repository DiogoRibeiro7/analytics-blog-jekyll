/** Enrich a static correction link with the section and selected passage. */
import { selectedQuote } from "./form.js";

export const MAX_URL_LENGTH = 1900;

function currentSection(content) {
  if (!content) return "";
  let section = "";
  content.querySelectorAll("h2, h3").forEach((heading) => {
    if (heading.getBoundingClientRect().top <= 0) section = heading.textContent.trim();
  });
  return section;
}

/** The original href already contains title, article URL and optional labels. */
export function enrichFallback(link, { window: win, content, quote = "" }) {
  const url = new URL(link.href, win.location.href);
  const key = link.dataset.correctionBodyParam;
  const body = url.searchParams.get(key);
  if (!body) return link.href;

  const section = currentSection(content);
  const sectionText = section ? `\n\n${link.dataset.correctionSectionLabel}: ${section}` : "";
  let passage = Array.from(quote || selectedQuote(win, content)).slice(0, 500).join("");
  const quoteLabel = link.dataset.correctionQuoteLabel;
  const address = () => {
    url.searchParams.set(key, `${body}${sectionText}${passage ? `\n\n${quoteLabel}: ${passage}` : ""}`);
    return url.href;
  };

  while (passage && address().length > MAX_URL_LENGTH) passage = Array.from(passage).slice(0, -20).join("");
  if (address().length > MAX_URL_LENGTH) url.searchParams.set(key, body);
  link.href = url.href;
  return link.href;
}

export function initCorrectionFallbacks(doc = document) {
  return Array.from(doc.querySelectorAll("[data-correction-fallback]")).map((link) => {
    const win = doc.defaultView;
    const content = doc.querySelector(".post-content");
    let pointerQuote = "";
    link.addEventListener("pointerdown", () => { pointerQuote = selectedQuote(win, content); });
    link.addEventListener("click", () => {
      enrichFallback(link, { window: win, content, quote: pointerQuote });
      pointerQuote = "";
    });
    return link;
  });
}
