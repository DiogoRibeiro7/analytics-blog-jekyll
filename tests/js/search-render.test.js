import { beforeEach, describe, expect, it, vi } from 'vitest';
import { renderResults } from '../../assets/js/search/render.js';

describe('renderResults', () => {
  let resultsList;
  let resultsMeta;
  let emptyState;
  let template;

  beforeEach(() => {
    document.body.innerHTML = '';

    resultsList = document.createElement('div');
    resultsMeta = document.createElement('div');
    emptyState = document.createElement('div');
    emptyState.hidden = true;

    // Create a template element with all possible data attributes
    template = document.createElement('template');
    template.innerHTML = `
      <article class="search-result">
        <div data-result-type></div>
        <div data-result-difficulty hidden></div>
        <div data-result-languages hidden></div>
        <a data-result-link href=""></a>
        <div data-result-summary></div>
        <div data-result-excerpt hidden></div>
        <div data-result-math hidden>
          <div data-result-math-preview></div>
          <code data-result-math-code></code>
          <button data-result-math-copy>
            <span class="visually-hidden">Copy LaTeX</span>
          </button>
        </div>
        <pre data-result-code hidden class="language-none">
          <code></code>
        </pre>
        <ul data-result-tags></ul>
        <div data-result-date hidden></div>
      </article>
    `;

    document.body.appendChild(resultsList);
    document.body.appendChild(resultsMeta);
    document.body.appendChild(emptyState);
    document.body.appendChild(template);
  });

  it('returns early when resultsList is null', () => {
    renderResults([], 'test', { resultsList: null, resultsMeta, emptyState, template });

    expect(resultsMeta.textContent).toBe('');
  });

  it('returns early when resultsMeta is null', () => {
    renderResults([], 'test', { resultsList, resultsMeta: null, emptyState, template });

    expect(resultsList.innerHTML).toBe('');
  });

  it('returns early when emptyState is null', () => {
    renderResults([], 'test', { resultsList, resultsMeta, emptyState: null, template });

    expect(resultsList.innerHTML).toBe('');
  });

  it('returns early when template is null', () => {
    renderResults([], 'test', { resultsList, resultsMeta, emptyState, template: null });

    expect(resultsList.innerHTML).toBe('');
  });

  it('displays prompt when query is empty', () => {
    renderResults([], '', { resultsList, resultsMeta, emptyState, template });

    expect(resultsMeta.textContent).toBe('Enter a query to begin.');
    expect(emptyState.hidden).toBe(true);
    expect(resultsList.innerHTML).toBe('');
  });

  it('displays no matches message when results are empty', () => {
    renderResults([], 'javascript', { resultsList, resultsMeta, emptyState, template });

    expect(resultsMeta.textContent).toContain('No matches for');
    expect(resultsMeta.textContent).toContain('javascript');
    expect(emptyState.hidden).toBe(false);
  });

  it('displays singular result count', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    expect(resultsMeta.textContent).toContain('1 result for');
    expect(resultsMeta.textContent).toContain('test');
    expect(emptyState.hidden).toBe(true);
  });

  it('displays plural result count', () => {
    const results = [
      { title: 'Test 1', url: '/test1', type: 'post' },
      { title: 'Test 2', url: '/test2', type: 'post' }
    ];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    expect(resultsMeta.textContent).toContain('2 results for');
    expect(resultsMeta.textContent).toContain('test');
  });

  it('renders result type correctly', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const typeEl = resultsList.querySelector('[data-result-type]');
    expect(typeEl.textContent).toBe('Tutorial & Blog');
  });

  it('renders difficulty when present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post', difficulty: 'advanced' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const difficultyEl = resultsList.querySelector('[data-result-difficulty]');
    expect(difficultyEl.textContent).toBe('Difficulty: Advanced');
    expect(difficultyEl.hidden).toBe(false);
  });

  it('hides difficulty when not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const difficultyEl = resultsList.querySelector('[data-result-difficulty]');
    expect(difficultyEl.hidden).toBe(true);
  });

  it('renders languages when present', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      languages: ['python', 'javascript']
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const languageEl = resultsList.querySelector('[data-result-languages]');
    expect(languageEl.textContent).toBe('Languages: Python, Javascript');
    expect(languageEl.hidden).toBe(false);
  });

  it('hides languages when not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const languageEl = resultsList.querySelector('[data-result-languages]');
    expect(languageEl.hidden).toBe(true);
  });

  it('renders link with title', () => {
    const results = [{ title: 'My Test Article', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const linkEl = resultsList.querySelector('[data-result-link]');
    expect(linkEl.textContent).toBe('My Test Article');
    expect(linkEl.getAttribute('href')).toBe('/test');
  });

  it('renders link with URL when title is missing', () => {
    const results = [{ url: '/test-article', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const linkEl = resultsList.querySelector('[data-result-link]');
    expect(linkEl.textContent).toBe('/test-article');
  });

  it('renders summary with highlighted query', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      summary: 'This is a test summary about javascript'
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const summaryEl = resultsList.querySelector('[data-result-summary]');
    expect(summaryEl.innerHTML).toContain('<mark>test</mark>');
  });

  it('renders excerpt when present', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      snippet: 'This is an excerpt with the test keyword'
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const excerptEl = resultsList.querySelector('[data-result-excerpt]');
    expect(excerptEl.innerHTML).toContain('<mark>test</mark>');
    expect(excerptEl.hidden).toBe(false);
  });

  it('hides excerpt when not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const excerptEl = resultsList.querySelector('[data-result-excerpt]');
    expect(excerptEl.hidden).toBe(true);
  });

  it('renders math snippet with DatalogMath', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      mathSnippet: '\\alpha + \\beta'
    }];

    window.DatalogMath = {
      renderLatex: vi.fn()
    };

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const mathEl = resultsList.querySelector('[data-result-math]');
    const mathCodeEl = resultsList.querySelector('[data-result-math-code]');
    const mathPreviewEl = resultsList.querySelector('[data-result-math-preview]');

    expect(mathEl.hidden).toBe(false);
    expect(mathCodeEl.textContent).toBe('\\alpha + \\beta');
    expect(window.DatalogMath.renderLatex).toHaveBeenCalledWith(
      mathPreviewEl,
      '\\alpha + \\beta',
      { display: false, enhance: false }
    );

    delete window.DatalogMath;
  });

  it('renders math snippet with MathJax', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      mathSnippet: '\\sum_{i=1}^n'
    }];

    window.MathJax = {
      typesetPromise: vi.fn().mockResolvedValue(undefined)
    };

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const mathPreviewEl = resultsList.querySelector('[data-result-math-preview]');

    expect(mathPreviewEl.innerHTML).toBe('\\(\\sum_{i=1}^n\\)');
    expect(window.MathJax.typesetPromise).toHaveBeenCalledWith([mathPreviewEl]);

    delete window.MathJax;
  });

  it('handles MathJax typesetPromise failure', async () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      mathSnippet: '\\invalid'
    }];

    const typesetPromiseMock = vi.fn().mockRejectedValue(new Error('MathJax error'));
    window.MathJax = {
      typesetPromise: typesetPromiseMock
    };

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const mathPreviewEl = resultsList.querySelector('[data-result-math-preview]');

    // Initial innerHTML is set before promise
    expect(mathPreviewEl.innerHTML).toBe('\\(\\invalid\\)');
    expect(typesetPromiseMock).toHaveBeenCalled();

    delete window.MathJax;
  }, 1000);

  it('renders math snippet as plain text when no rendering library available', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      mathSnippet: 'x^2 + y^2'
    }];

    // Ensure no rendering libraries are available
    delete window.DatalogMath;
    delete window.MathJax;

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const mathEl = resultsList.querySelector('[data-result-math]');
    const mathPreviewEl = resultsList.querySelector('[data-result-math-preview]');
    expect(mathEl.hidden).toBe(false);
    expect(mathPreviewEl.textContent).toBe('x^2 + y^2');
  });

  it('hides math section when mathSnippet is not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const mathEl = resultsList.querySelector('[data-result-math]');
    expect(mathEl.hidden).toBe(true);
  });

  it('attaches copy handler to math copy button', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      mathSnippet: '\\pi'
    }];

    // Mock clipboard API
    const writeTextMock = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText: writeTextMock },
      writable: true,
      configurable: true
    });

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const copyButton = resultsList.querySelector('[data-result-math-copy]');
    copyButton.click();

    expect(writeTextMock).toHaveBeenCalledWith('\\pi');
  });

  it('renders code snippet with Prism highlighting', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      codeSnippet: {
        code: 'function test() { return 42; }',
        language: 'javascript'
      }
    }];

    window.Prism = {
      languages: {
        javascript: {},
        markup: {}
      },
      highlight: vi.fn((code, grammar, lang) => `<span class="token">${code}</span>`)
    };

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const codeEl = resultsList.querySelector('[data-result-code]');
    const codeCodeEl = codeEl.querySelector('code');

    expect(codeEl.hidden).toBe(false);
    expect(codeEl.classList.contains('language-javascript')).toBe(true);
    expect(codeCodeEl.className).toBe('language-javascript');
    expect(window.Prism.highlight).toHaveBeenCalledWith(
      'function test() { return 42; }',
      {},
      'javascript'
    );

    delete window.Prism;
  });

  it('renders code snippet with fallback when Prism is not available', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      codeSnippet: {
        code: 'def hello():\n    print("world")',
        language: 'python'
      }
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const codeCodeEl = resultsList.querySelector('[data-result-code] code');
    expect(codeCodeEl.textContent).toBe('def hello():\n    print("world")');
  });

  it('uses text language as fallback when language is not specified', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      codeSnippet: {
        code: 'some code'
      }
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const codeEl = resultsList.querySelector('[data-result-code]');
    expect(codeEl.classList.contains('language-text')).toBe(true);
  });

  it('hides code section when codeSnippet is not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const codeEl = resultsList.querySelector('[data-result-code]');
    expect(codeEl.hidden).toBe(true);
  });

  it('renders tags', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      tags: ['machine-learning', 'python', 'tutorial']
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const tagsEl = resultsList.querySelector('[data-result-tags]');
    const tagItems = tagsEl.querySelectorAll('li');

    expect(tagItems.length).toBe(3);
    expect(tagItems[0].textContent).toBe('#machine-learning');
    expect(tagItems[1].textContent).toBe('#python');
    expect(tagItems[2].textContent).toBe('#tutorial');
  });

  it('handles empty tags array', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      tags: []
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const tagsEl = resultsList.querySelector('[data-result-tags]');
    expect(tagsEl.innerHTML).toBe('');
  });

  it('renders date when present', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      date: '2024-01-15'
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const dateEl = resultsList.querySelector('[data-result-date]');
    expect(dateEl.textContent).toMatch(/(?:Jan.*15|15.*Jan).*2024/);
    expect(dateEl.hidden).toBe(false);
  });

  it('hides date when not present', () => {
    const results = [{ title: 'Test', url: '/test', type: 'post' }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const dateEl = resultsList.querySelector('[data-result-date]');
    expect(dateEl.hidden).toBe(true);
  });

  it('hides date when date is invalid', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      date: 'invalid-date'
    }];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const dateEl = resultsList.querySelector('[data-result-date]');
    expect(dateEl.hidden).toBe(true);
  });

  it('renders multiple results', () => {
    const results = [
      { title: 'Test 1', url: '/test1', type: 'post' },
      { title: 'Test 2', url: '/test2', type: 'project' },
      { title: 'Test 3', url: '/test3', type: 'research' }
    ];

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    const articles = resultsList.querySelectorAll('.search-result');
    expect(articles.length).toBe(3);
  });

  it('clears previous results before rendering new ones', () => {
    const results1 = [{ title: 'Test 1', url: '/test1', type: 'post' }];
    const results2 = [
      { title: 'Test 2', url: '/test2', type: 'post' },
      { title: 'Test 3', url: '/test3', type: 'post' }
    ];

    renderResults(results1, 'test', { resultsList, resultsMeta, emptyState, template });
    expect(resultsList.querySelectorAll('.search-result').length).toBe(1);

    renderResults(results2, 'test', { resultsList, resultsMeta, emptyState, template });
    expect(resultsList.querySelectorAll('.search-result').length).toBe(2);
  });

  it('uses Prism.languages.markup as fallback when language grammar is not available', () => {
    const results = [{
      title: 'Test',
      url: '/test',
      type: 'post',
      codeSnippet: {
        code: 'some unknown language code',
        language: 'unknownlang'
      }
    }];

    window.Prism = {
      languages: {
        markup: {}
      },
      highlight: vi.fn((code) => code)
    };

    renderResults(results, 'test', { resultsList, resultsMeta, emptyState, template });

    expect(window.Prism.highlight).toHaveBeenCalledWith(
      'some unknown language code',
      {},
      'unknownlang'
    );

    delete window.Prism;
  });
});
