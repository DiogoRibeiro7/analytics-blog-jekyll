import { beforeEach, describe, expect, it } from 'vitest';
import { createSearchEngine } from '../../assets/js/search/engine.js';
import { renderResults } from '../../assets/js/search/render.js';

/**
 * A search result used to point at a whole page. For a long methods post that
 * hands the reader a second search problem: find the paragraph. A result now
 * lists the sections of the page its words were in, each linking to the
 * heading (#336).
 */

const URL = '/2024/04/09/experimental-design/';

const SECTIONS = [
  { title: '', anchor: null, level: 0, content: 'An opening that mentions nothing in particular.' },
  {
    title: 'Checking for heteroscedasticity',
    anchor: 'checking-for-heteroscedasticity',
    level: 2,
    content: 'Residual spread grows with the fitted value, so heteroscedasticity breaks the constant-variance assumption.'
  },
  {
    title: 'Choosing a test',
    anchor: 'choosing-a-test',
    level: 3,
    content: 'A Breusch-Pagan test is the usual first move.'
  },
  {
    title: 'Reporting the result',
    anchor: 'reporting-the-result',
    level: 2,
    content: 'Give the statistic and the p-value from the test.'
  }
];

// A page's flattened text is its sections joined, which is how the index
// builds it. Deriving it here keeps a fixture from claiming a section the page
// itself does not contain.
function article(sections = SECTIONS, overrides = {}) {
  return {
    title: 'Experimental design and statistical tests',
    url: URL,
    type: 'post',
    summary: 'Designing an experiment and reading its results.',
    content: sections.map((section) => `${section.title} ${section.content}`.trim()).join(' '),
    sections,
    ...overrides
  };
}

function searchFor(query, doc = article()) {
  return createSearchEngine([doc]).search(query);
}

describe('sections in a result', () => {
  it('lists the sections the words were in', () => {
    const [result] = searchFor('heteroscedasticity');

    expect(result.sections.map((section) => section.title)).toEqual(['Checking for heteroscedasticity']);
    expect(result.sections[0].url).toBe(`${URL}#checking-for-heteroscedasticity`);
  });

  it('keeps the page as the one result, not one result per section', () => {
    const results = searchFor('value');

    expect(results).toHaveLength(1);
    expect(results[0].url).toBe(URL);
  });

  it('puts the section whose heading matches ahead of one that only mentions the word', () => {
    const [result] = searchFor('test');
    const titles = result.sections.map((section) => section.title);

    expect(titles[0]).toBe('Choosing a test');
    expect(titles).toContain('Reporting the result');
  });

  // The text before the first heading is the page, which is already the result
  // it would sit under.
  it('never offers the untitled opening as a section', () => {
    const [result] = searchFor('opening');

    expect(result.sections).toEqual([]);
  });

  it('lists at most three, so the result list stays the length it was', () => {
    const many = Array.from({ length: 9 }, (_, index) => ({
      title: `Section ${index}`,
      anchor: `section-${index}`,
      level: 2,
      content: 'variance everywhere'
    }));
    const [result] = searchFor('variance', article(many));

    expect(result.sections).toHaveLength(3);
  });

  it('links to the page when the heading had no id to link to', () => {
    const sections = [{ title: 'Languages', anchor: null, level: 2, content: 'Python and R.' }];
    const [result] = searchFor('python', article(sections));

    expect(result.sections[0].title).toBe('Languages');
    expect(result.sections[0].url).toBe(URL);
  });

  // "1. Introduction" gives id="1-introduction". It is a fine URL fragment and
  // a broken CSS identifier; the link is an href, so it is used as it is.
  it('deep-links to a heading id that starts with a digit', () => {
    const sections = [{ title: '1. Introduction', anchor: '1-introduction', level: 2, content: 'A preamble.' }];
    const [result] = searchFor('preamble', article(sections));

    expect(result.sections[0].url).toBe(`${URL}#1-introduction`);
  });

  it('takes the excerpt from the section rather than the whole page', () => {
    const [result] = searchFor('Breusch-Pagan');

    expect(result.snippet).toContain('the usual first move');
    expect(result.snippet).not.toContain('An opening that mentions');
  });

  // An index written before sections existed, or one a site generates itself.
  it('searches a document that has no sections at all', () => {
    const [result] = searchFor('heteroscedasticity', article(SECTIONS, { sections: undefined }));

    expect(result).toBeTruthy();
    expect(result.sections).toEqual([]);
    expect(result.snippet).toContain('heteroscedasticity');
  });

  it('offers no sections for a query that only the title matched', () => {
    const [result] = searchFor('Experimental');

    expect(result.sections).toEqual([]);
  });
});

describe('rendering the sections of a result', () => {
  let elements;

  beforeEach(() => {
    document.body.innerHTML = `
      <ol data-search-results></ol>
      <p data-search-meta></p>
      <div data-search-empty hidden></div>
      <template id="tpl">
        <li data-result-item>
          <a data-result-link></a>
          <p data-result-summary></p>
          <p data-result-excerpt></p>
          <div class="search-result__sections" data-result-sections hidden>
            <p data-result-sections-label></p>
            <ul></ul>
          </div>
        </li>
      </template>`;
    elements = {
      resultsList: document.querySelector('[data-search-results]'),
      resultsMeta: document.querySelector('[data-search-meta]'),
      emptyState: document.querySelector('[data-search-empty]'),
      template: document.getElementById('tpl')
    };
  });

  function render(query, doc = article()) {
    renderResults(createSearchEngine([doc]).search(query), query, elements);
  }

  it('shows a link per matching section', () => {
    render('test');
    const links = document.querySelectorAll('[data-result-sections] a');

    expect(links.length).toBe(2);
    expect(links[0].getAttribute('href')).toBe(`${URL}#choosing-a-test`);
    expect(document.querySelector('[data-result-sections]').hidden).toBe(false);
  });

  it('names the list for one section and for several', () => {
    render('heteroscedasticity');
    expect(document.querySelector('[data-result-sections-label]').textContent).toBe('Matching section');

    render('test');
    expect(document.querySelector('[data-result-sections-label]').textContent).toBe('Matching sections');
  });

  it('stays hidden when the query matched no section', () => {
    render('Experimental');

    expect(document.querySelector('[data-result-sections]').hidden).toBe(true);
  });

  it('marks the query in the heading and in the section excerpt', () => {
    render('heteroscedasticity');
    const item = document.querySelector('[data-result-sections] li');

    expect(item.querySelector('a mark').textContent.toLowerCase()).toBe('heteroscedasticity');
    expect(item.querySelector('.search-result__section-snippet mark')).toBeTruthy();
  });

  it('carries the heading level, so the shape of the article shows', () => {
    render('Breusch-Pagan');
    const item = document.querySelector('[data-result-sections] li');

    expect(item.className).toContain('search-result__section--h3');
  });

  // A section title is page content, and page content is never markup here.
  it('escapes a section title rather than parsing it', () => {
    const sections = [
      { title: '<img src=x onerror=alert(1)>', anchor: 'x', level: 2, content: 'A payload of sorts.' }
    ];
    render('payload', article(sections));

    expect(document.querySelector('[data-result-sections] img')).toBeNull();
    expect(document.querySelector('[data-result-sections] a').textContent).toContain('onerror');
  });
});
