import { beforeEach, describe, expect, it } from "vitest";
import { enrichFallback, initCorrectionFallbacks, MAX_URL_LENGTH } from "../../assets/js/corrections/fallback.js";

const body = "Article: A post\nAddress: https://example.org/post/\n\nDescribe the correction.";

function mount(href, bodyParam = "body") {
  document.body.innerHTML = `
    <article class="post-content"><h2>Introduction</h2><p>A wrong claim.</p><h2>Method</h2></article>
    <a data-correction-fallback data-correction-body-param="${bodyParam}"
      data-correction-section-label="Section" data-correction-quote-label="Selected passage">Report</a>`;
  const link = document.querySelector("[data-correction-fallback]");
  link.href = href;
  return link;
}

beforeEach(() => {
  document.body.innerHTML = "";
  window.getSelection()?.removeAllRanges();
});

describe("correction fallback", () => {
  it("keeps a usable static link and enriches it on activation", () => {
    const link = mount(`https://github.com/a/b/issues/new?${new URLSearchParams({ title: "Correction", body, labels: "correction" })}`);
    const headings = document.querySelectorAll("h2");
    headings[0].getBoundingClientRect = () => ({ top: -200 });
    headings[1].getBoundingClientRect = () => ({ top: -10 });
    const range = document.createRange();
    range.selectNodeContents(document.querySelector(".post-content p"));
    window.getSelection().addRange(range);

    expect(new URL(link.href).searchParams.get("body")).toBe(body);
    expect(initCorrectionFallbacks()).toHaveLength(1);
    link.dispatchEvent(new Event("pointerdown"));
    window.getSelection().removeAllRanges();
    link.dispatchEvent(new Event("click", { cancelable: true }));

    const url = new URL(link.href);
    expect(url.searchParams.get("body")).toContain("Section: Method");
    expect(url.searchParams.get("body")).toContain("Selected passage: A wrong claim.");
    expect(url.searchParams.get("labels")).toBe("correction");
  });

  it("encodes GitLab fields and email bodies, and caps long selected text", () => {
    const gitlab = mount(`https://gitlab.com/a/b/-/issues/new?${new URLSearchParams({ "issue[title]": "Correction", "issue[description]": body })}`, "issue[description]");
    const text = enrichFallback(gitlab, { window, content: document.querySelector(".post-content"), quote: "✓ & 漢".repeat(300) });
    expect(text.length).toBeLessThanOrEqual(MAX_URL_LENGTH);
    expect(new URL(text).searchParams.get("issue[description]")).toContain("Selected passage:");

    const email = mount(`mailto:reader@example.org?${new URLSearchParams({ subject: "Correction", body })}`);
    const mailto = enrichFallback(email, { window, content: null, quote: "some text & more" });
    expect(new URL(mailto).searchParams.get("body")).toContain("Selected passage: some text & more");
  });
});
