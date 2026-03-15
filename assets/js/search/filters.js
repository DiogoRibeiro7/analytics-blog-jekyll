export function renderTagFilters(container, documents, selectedTags) {
  if (!container) {
    return;
  }

  const tagSet = new Set();
  documents.forEach((item) => {
    const source = item.tags || item.topics || [];
    source.forEach((tag) => {
      if (tag) {
        tagSet.add(String(tag).toLowerCase());
      }
    });
  });

  const tags = Array.from(tagSet).sort();
  if (tags.length === 0) {
    container.innerHTML = '<p class="search-filter__empty">No tags available yet.</p>';
    return;
  }

  const fragment = document.createDocumentFragment();
  tags.forEach((tag) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "search-filter__tag";
    button.textContent = tag;
    button.dataset.filterTag = tag;
    button.setAttribute("aria-pressed", selectedTags.has(tag) ? "true" : "false");
    fragment.appendChild(button);
  });

  container.innerHTML = "";
  container.appendChild(fragment);
}
