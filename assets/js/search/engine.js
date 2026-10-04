import {
  buildSnippet,
  fuzzyIncludes,
  isCodeQuery,
  isMathQuery,
  normalize,
  normalizeCode,
  tokenize
} from "./utils.js";

// A result lists at most this many of the sections it matched. Enough to
// show a reader where in a long article their words are; few enough that the
// result list stays the length it was.
const MAX_SECTION_LINKS = 3;

export function createSearchEngine(initialDocuments = []) {
  let documents = Array.isArray(initialDocuments) ? [...initialDocuments] : [];

  function setDocuments(nextDocuments) {
    documents = Array.isArray(nextDocuments) ? [...nextDocuments] : [];
  }

  function search(rawQuery, filters = {}) {
    const query = (rawQuery || "").trim();
    if (!query) {
      return [];
    }

    const normalizedQuery = normalize(query);
    const queryTokens = tokenize(query);
    const mathQuery = isMathQuery(query);
    const codeQuery = isCodeQuery(query);
    const {
      type: typeFilter = "",
      language: languageFilter = "",
      difficulty: difficultyFilter = "",
      tags: selectedTags = new Set()
    } = filters;

    return documents
      .map((doc) =>
        evaluateDocument(doc, {
          rawQuery: query,
          normalizedQuery,
          queryTokens,
          mathQuery,
          codeQuery,
          typeFilter,
          languageFilter,
          difficultyFilter,
          selectedTags
        })
      )
      .filter((match) => match && match.score > 0)
      .sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
  }

  function suggestions(limit = 150) {
    return buildSuggestionPool(documents, limit);
  }

  function getDocuments() {
    return [...documents];
  }

  return { setDocuments, search, suggestions, getDocuments };
}

export function buildSuggestionPool(items = [], limit = 150) {
  const suggestionSet = new Set();
  items.forEach((item) => {
    if (item.title) {
      suggestionSet.add(item.title);
    }
    if (Array.isArray(item.languages)) {
      item.languages.forEach((lang) => suggestionSet.add(lang));
    }
    if (Array.isArray(item.tags)) {
      item.tags.forEach((tag) => suggestionSet.add(`#${tag}`));
    }
    if (Array.isArray(item.math)) {
      item.math.slice(0, 3).forEach((expression) => suggestionSet.add(expression));
    }
  });
  return Array.from(suggestionSet).slice(0, limit);
}

function evaluateDocument(doc, context) {
  const {
    rawQuery,
    normalizedQuery,
    queryTokens,
    mathQuery,
    codeQuery,
    typeFilter,
    languageFilter,
    difficultyFilter,
    selectedTags
  } = context;

  if (typeFilter && doc.type !== typeFilter) {
    return null;
  }

  const docLanguages = Array.isArray(doc.languages) ? doc.languages : [];
  if (languageFilter && !docLanguages.includes(languageFilter)) {
    return null;
  }

  if (difficultyFilter) {
    const difficulty = String(doc.difficulty || "").toLowerCase();
    if (!difficulty || difficulty !== difficultyFilter) {
      return null;
    }
  }

  if (selectedTags && selectedTags.size > 0) {
    const normalizedTags = new Set(normalizedFields(doc).tags);
    for (const tag of selectedTags) {
      if (!normalizedTags.has(tag)) {
        return null;
      }
    }
  }

  if (!rawQuery) {
    return null;
  }

  const {
    title: normalizedTitle,
    summary: normalizedSummary,
    content: normalizedContent,
    tags: normalizedTags,
    languages: normalizedLanguages,
    difficulty: normalizedDifficulty
  } = normalizedFields(doc);
  const codeBlocks = Array.isArray(doc.code) ? doc.code : [];
  const mathSegments = Array.isArray(doc.math) ? doc.math : [];
  // A match in a section is a match in its page, so the two are not separate
  // results: the page is the result and its sections hang off it.
  const scoredSections = scoreSections(doc, { rawQuery, normalizedQuery, queryTokens });
  const sectionSnippet = (scoredSections.find((section) => section.snippet) || {}).snippet || "";

  let score = 0;
  let snippet = "";
  let codeSnippet = null;
  let mathSnippet = null;

  if (normalizedTitle.includes(normalizedQuery)) {
    score += 40;
  }

  queryTokens.forEach((token) => {
    if (!token) {
      return;
    }
    if (normalizedTitle.includes(token)) {
      score += 12;
    }
    if (normalizedSummary.includes(token)) {
      score += 8;
    }
    if (normalizedContent.includes(token)) {
      score += 6;
    }
    normalizedTags.forEach((tag) => {
      if (tag.includes(token)) {
        score += 4;
      }
    });
    normalizedLanguages.forEach((lang) => {
      if (lang.includes(token)) {
        score += 4;
      }
    });
    if (normalizedDifficulty.includes(token)) {
      score += 2;
    }
  });

  if (codeBlocks.length > 0) {
    const normalizedCodeQuery = normalizeCode(rawQuery);
    for (const block of codeBlocks) {
      const language = String(block.language || "").toLowerCase();
      const codeText = block.code || "";
      const normalizedCode = normalizeCode(codeText);
      if (normalizedCode.includes(normalizedCodeQuery)) {
        score += 30;
        codeSnippet = { language, code: codeText };
        break;
      }
      if (codeQuery && fuzzyIncludes(normalizedCode, normalizedCodeQuery)) {
        score += 18;
        codeSnippet = { language, code: codeText };
        break;
      }
    }
    if (!codeSnippet && codeBlocks[0]) {
      codeSnippet = {
        language: String(codeBlocks[0].language || "").toLowerCase(),
        code: codeBlocks[0].code || ""
      };
    }
  }

  if (mathSegments.length > 0) {
    const normalizedMathQuery = normalizedQuery.replace(/\\/g, "");
    for (const expression of mathSegments) {
      const normalizedExpression = normalize(String(expression));
      if (normalizedExpression.includes(normalizedMathQuery)) {
        score += 26;
        mathSnippet = expression;
        break;
      }
    }
    if (mathQuery && !mathSnippet && mathSegments[0]) {
      mathSnippet = mathSegments[0];
      score += 10;
    }
  }

  if (normalizedContent.includes(normalizedQuery)) {
    const index = normalizedContent.indexOf(normalizedQuery);
    // The section's own text is a tighter excerpt than the whole page's.
    snippet = sectionSnippet || buildSnippet(doc.content || "", index, rawQuery.length);
    score += 10;
  } else if (normalizedSummary.includes(normalizedQuery)) {
    const index = normalizedSummary.indexOf(normalizedQuery);
    snippet = buildSnippet(doc.summary || "", index, rawQuery.length);
    score += 6;
  }

  if (score === 0) {
    return null;
  }

  return {
    id: `${doc.url}`,
    title: doc.title,
    url: doc.url,
    summary: doc.summary,
    snippet,
    codeSnippet,
    mathSnippet,
    tags: doc.tags || [],
    languages: doc.languages || [],
    difficulty: doc.difficulty || "",
    type: doc.type || "page",
    date: doc.date,
    readingTime: doc.reading_time,
    // The text before the first heading has no title and nothing to link to;
    // it is the page, which is already this result.
    sections: scoredSections.filter((section) => section.title).slice(0, MAX_SECTION_LINKS),
    score
  };
}

// Every section that matched, best first. An index written before sections
// existed, or one a site generates itself, simply has none.
function scoreSections(doc, context) {
  const sections = Array.isArray(doc.sections) ? doc.sections : [];
  if (sections.length === 0) {
    return [];
  }
  return sections
    .map((section) => scoreSection(doc, section, context))
    .filter((match) => match !== null)
    .sort((a, b) => b.score - a.score);
}

function scoreSection(doc, section, { rawQuery, normalizedQuery, queryTokens }) {
  const { title, content } = normalizedSection(section);
  if (!title && !content) {
    return null;
  }

  let score = 0;
  if (title && title.includes(normalizedQuery)) {
    score += 24;
  }
  queryTokens.forEach((token) => {
    if (!token) {
      return;
    }
    if (title.includes(token)) {
      score += 8;
    }
    if (content.includes(token)) {
      score += 3;
    }
  });

  let snippet = "";
  const index = content.indexOf(normalizedQuery);
  if (index >= 0) {
    score += 6;
    snippet = buildSnippet(section.content || "", index, rawQuery.length);
  }

  if (score === 0) {
    return null;
  }

  return { title: section.title || "", url: sectionUrl(doc, section), level: section.level || 2, snippet, score };
}

// kramdown will happily give a heading the id "1-introduction", which is not a
// valid CSS identifier. A fragment in an href is the one place that never
// minds: nothing here hands it to querySelector, which is what made the
// contents list's links dead (#330).
function sectionUrl(doc, section) {
  const anchor = section.anchor;
  return anchor ? `${doc.url}#${encodeURIComponent(anchor)}` : doc.url;
}

const normalizedSections = new WeakMap();

function normalizedSection(section) {
  const cached = normalizedSections.get(section);
  if (cached) {
    return cached;
  }
  const fields = { title: normalize(section.title || ""), content: normalize(section.content || "") };
  normalizedSections.set(section, fields);
  return fields;
}

// search.json carries each text field once. Its normalized form is worked out
// the first time a document is searched and kept for the queries that follow,
// with the same normalize() the query goes through. An index that still ships
// a precomputed `normalized` object is used as it is.
const normalizedCache = new WeakMap();

function normalizedFields(doc) {
  const cached = normalizedCache.get(doc);
  if (cached) {
    return cached;
  }
  const precomputed = doc.normalized || {};
  const fields = {
    title: precomputed.title || normalize(doc.title || ""),
    summary: precomputed.summary || normalize(doc.summary || ""),
    content: precomputed.content || normalize(doc.content || ""),
    tags: arrayFromNormalized(precomputed.tags, doc.tags),
    languages: arrayFromNormalized(precomputed.languages, doc.languages),
    difficulty: precomputed.difficulty || normalize(doc.difficulty || "")
  };
  normalizedCache.set(doc, fields);
  return fields;
}

function arrayFromNormalized(normalizedValues, fallback) {
  if (Array.isArray(normalizedValues) && normalizedValues.length > 0) {
    return normalizedValues;
  }
  return Array.isArray(fallback) ? fallback.map((value) => normalize(value)) : [];
}
