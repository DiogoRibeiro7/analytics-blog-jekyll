import { describe, it, expect, beforeEach } from 'vitest';
import { renderTagFilters } from '../../assets/js/search/filters.js';
import {
  normalize,
  normalizeCode,
  tokenize,
  isMathQuery,
  isCodeQuery,
  fuzzyIncludes,
  stripHtml,
  buildSnippet,
  escapeRegex,
  highlightText,
  toTitleCase,
  formatType
} from '../../assets/js/search/utils.js';

describe('Search Filters Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('should render tag filters from documents', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['javascript', 'python'] },
      { tags: ['r', 'statistics'] },
      { tags: ['javascript', 'data-science'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = container.querySelectorAll('.search-filter__tag');
    expect(buttons.length).toBe(5); // javascript, python, r, statistics, data-science
  });

  it('should handle topics field as fallback', () => {
    const container = document.createElement('div');
    const documents = [
      { topics: ['machine-learning', 'ai'] },
      { topics: ['deep-learning'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = container.querySelectorAll('.search-filter__tag');
    expect(buttons.length).toBe(3);
  });

  it('should normalize tags to lowercase', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['JavaScript', 'PYTHON', 'R'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = Array.from(container.querySelectorAll('.search-filter__tag'));
    const tagTexts = buttons.map(b => b.textContent);
    expect(tagTexts).toContain('javascript');
    expect(tagTexts).toContain('python');
    expect(tagTexts).toContain('r');
  });

  it('should sort tags alphabetically', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['zebra', 'apple', 'banana'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = Array.from(container.querySelectorAll('.search-filter__tag'));
    const tagTexts = buttons.map(b => b.textContent);
    expect(tagTexts).toEqual(['apple', 'banana', 'zebra']);
  });

  it('should mark selected tags with aria-pressed', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['javascript', 'python', 'r'] }
    ];
    const selectedTags = new Set(['python']);

    renderTagFilters(container, documents, selectedTags);

    const pythonButton = Array.from(container.querySelectorAll('.search-filter__tag'))
      .find(b => b.textContent === 'python');
    expect(pythonButton.getAttribute('aria-pressed')).toBe('true');

    const jsButton = Array.from(container.querySelectorAll('.search-filter__tag'))
      .find(b => b.textContent === 'javascript');
    expect(jsButton.getAttribute('aria-pressed')).toBe('false');
  });

  it('should remove duplicates', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['javascript', 'python'] },
      { tags: ['javascript', 'python'] },
      { tags: ['javascript'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = container.querySelectorAll('.search-filter__tag');
    expect(buttons.length).toBe(2); // Only javascript and python
  });

  it('should show empty message when no tags exist', () => {
    const container = document.createElement('div');
    const documents = [];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    expect(container.innerHTML).toContain('No tags available yet');
  });

  it('should filter out null/undefined tags', () => {
    const container = document.createElement('div');
    const documents = [
      { tags: ['javascript', null, undefined, '', 'python'] }
    ];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const buttons = container.querySelectorAll('.search-filter__tag');
    expect(buttons.length).toBe(2); // Only javascript and python
  });

  it('should do nothing when container is null', () => {
    const documents = [{ tags: ['test'] }];
    const selectedTags = new Set();

    expect(() => renderTagFilters(null, documents, selectedTags)).not.toThrow();
  });

  it('should set correct data attributes', () => {
    const container = document.createElement('div');
    const documents = [{ tags: ['test-tag'] }];
    const selectedTags = new Set();

    renderTagFilters(container, documents, selectedTags);

    const button = container.querySelector('.search-filter__tag');
    expect(button.dataset.filterTag).toBe('test-tag');
  });
});

describe('Search Utils Module', () => {
  describe('normalize()', () => {
    it('should convert to lowercase', () => {
      expect(normalize('HELLO')).toBe('hello');
    });

    it('should remove diacritics', () => {
      expect(normalize('café')).toBe('cafe');
      expect(normalize('naïve')).toBe('naive');
      expect(normalize('résumé')).toBe('resume');
    });

    it('should handle null/undefined', () => {
      expect(normalize(null)).toBe('');
      expect(normalize(undefined)).toBe('');
      expect(normalize()).toBe('');
    });

    it('should convert numbers to strings', () => {
      expect(normalize(123)).toBe('123');
    });

    it('should handle empty strings', () => {
      expect(normalize('')).toBe('');
    });
  });

  describe('normalizeCode()', () => {
    it('should remove whitespace from code', () => {
      expect(normalizeCode('function test() {}')).toBe('functiontest(){}');
    });

    it('should normalize and remove spaces', () => {
      expect(normalizeCode('HELLO WORLD')).toBe('helloworld');
    });

    it('should handle multiple spaces and tabs', () => {
      expect(normalizeCode('a  b\tc\nd')).toBe('abcd');
    });
  });

  describe('tokenize()', () => {
    it('should split query into tokens', () => {
      const tokens = tokenize('hello world test');
      expect(tokens).toEqual(['hello', 'world', 'test']);
    });

    it('should remove special characters', () => {
      const tokens = tokenize('hello, world! test?');
      expect(tokens).toEqual(['hello', 'world', 'test']);
    });

    it('should preserve dots and underscores', () => {
      const tokens = tokenize('test_var some.method');
      expect(tokens).toContain('test_var');
      expect(tokens).toContain('some.method');
    });

    it('should handle empty query', () => {
      expect(tokenize()).toEqual([]);
      expect(tokenize('')).toEqual([]);
    });

    it('should normalize before tokenizing', () => {
      const tokens = tokenize('HELLO WoRLd');
      expect(tokens).toEqual(['hello', 'world']);
    });

    it('keeps words in any script', () => {
      expect(tokenize('Łódź café Привет')).toEqual(['łodz', 'cafe', 'привет']);
    });
  });

  describe('isMathQuery()', () => {
    it('should detect LaTeX syntax', () => {
      expect(isMathQuery('\\alpha')).toBe(true);
      expect(isMathQuery('x^2')).toBe(true);
      expect(isMathQuery('a_n')).toBe(true);
      expect(isMathQuery('\\frac{a}{b}')).toBe(true);
      expect(isMathQuery('$x = 5$')).toBe(true);
    });

    it('should return false for non-math queries', () => {
      expect(isMathQuery('hello world')).toBe(false);
      expect(isMathQuery('python code')).toBe(false);
    });

    it('should handle empty queries', () => {
      expect(isMathQuery()).toBe(false);
      expect(isMathQuery('')).toBe(false);
    });
  });

  describe('isCodeQuery()', () => {
    it('should detect code syntax', () => {
      expect(isCodeQuery('function test()')).toBe(true);
      expect(isCodeQuery('def method()')).toBe(true);
      expect(isCodeQuery('class MyClass')).toBe(true);
      expect(isCodeQuery('x => y')).toBe(true);
      expect(isCodeQuery('a -> b')).toBe(true);
      expect(isCodeQuery('array[0]')).toBe(true);
      expect(isCodeQuery('obj.method()')).toBe(true);
      expect(isCodeQuery('let x = 5')).toBe(true);
    });

    it('should detect backticks', () => {
      expect(isCodeQuery('`code`')).toBe(true);
    });

    it('should return false for non-code queries', () => {
      expect(isCodeQuery('hello world')).toBe(false);
    });
  });

  describe('fuzzyIncludes()', () => {
    it('should match exact sequences', () => {
      expect(fuzzyIncludes('hello', 'hel')).toBe(true);
      expect(fuzzyIncludes('javascript', 'java')).toBe(true);
    });

    it('should match fuzzy patterns', () => {
      expect(fuzzyIncludes('javascript', 'jvspt')).toBe(true);
      expect(fuzzyIncludes('hello world', 'hwd')).toBe(true);
    });

    it('should return false for non-matches', () => {
      expect(fuzzyIncludes('hello', 'xyz')).toBe(false);
    });

    it('should handle empty inputs', () => {
      expect(fuzzyIncludes('', 'test')).toBe(false);
      expect(fuzzyIncludes('test', '')).toBe(false);
      expect(fuzzyIncludes(null, 'test')).toBe(false);
    });
  });

  describe('stripHtml()', () => {
    it('should remove HTML tags', () => {
      expect(stripHtml('<p>Hello</p>')).toBe('Hello');
      expect(stripHtml('<strong>Bold</strong> text')).toBe('Bold text');
    });

    it('should handle nested tags', () => {
      expect(stripHtml('<div><p>Test</p></div>')).toBe('Test');
    });

    it('should handle empty/null values', () => {
      expect(stripHtml('')).toBe('');
      expect(stripHtml(null)).toBe('');
      expect(stripHtml(undefined)).toBe('');
    });

    it('should preserve text content', () => {
      expect(stripHtml('Plain text')).toBe('Plain text');
    });
  });

  describe('buildSnippet()', () => {
    it('should extract snippet around index', () => {
      const content = 'A'.repeat(200);
      const snippet = buildSnippet(content, 100, 10);
      expect(snippet.length).toBeLessThanOrEqual(200); // 80 before + 10 match + 80 after + possible ellipsis
    });

    it('should add ellipsis when content continues', () => {
      const content = 'A'.repeat(500);
      const snippet = buildSnippet(content, 50, 10);
      expect(snippet).toContain('…');
    });

    it('should handle start of content', () => {
      const content = 'Hello world test';
      const snippet = buildSnippet(content, 0, 5);
      expect(snippet).toBe('Hello world test');
    });

    it('should strip HTML from content', () => {
      const content = '<p>Hello world</p>';
      const snippet = buildSnippet(content, 0, 5);
      expect(snippet).not.toContain('<p>');
      expect(snippet).toContain('Hello');
    });

    it('should handle empty content', () => {
      expect(buildSnippet('', 0, 0)).toBe('');
      expect(buildSnippet(null, 0, 0)).toBe('');
    });
  });

  describe('escapeRegex()', () => {
    it('should escape special regex characters', () => {
      expect(escapeRegex('.*+?^${}()|[]')).toBe('\\.\\*\\+\\?\\^\\$\\{\\}\\(\\)\\|\\[\\]');
    });

    it('should not modify regular text', () => {
      expect(escapeRegex('hello')).toBe('hello');
    });
  });

  describe('highlightText()', () => {
    it('should wrap matched words in mark tags', () => {
      const result = highlightText('hello world', 'hello');
      expect(result).toContain('<mark>hello</mark>');
    });

    it('should be case-insensitive', () => {
      const result = highlightText('Hello World', 'HELLO');
      expect(result).toContain('<mark>Hello</mark>');
    });

    it('should highlight multiple matches', () => {
      const result = highlightText('test test test', 'test');
      const matches = (result.match(/<mark>/g) || []).length;
      expect(matches).toBe(3);
    });

    it('should handle multiple query terms', () => {
      const result = highlightText('hello world test', 'hello test');
      expect(result).toContain('<mark>hello</mark>');
      expect(result).toContain('<mark>test</mark>');
    });

    it('should handle empty inputs', () => {
      expect(highlightText('', 'test')).toBe('');
      expect(highlightText('hello', '')).toBe('hello');
      expect(highlightText(null, 'test')).toBe('');
    });

    it('escapes the text, so markup from the index is shown rather than parsed', () => {
      expect(highlightText('<img src=x onerror=alert(1)> title', 'title'))
        .toBe('&lt;img src=x onerror=alert(1)&gt; <mark>title</mark>');
    });

    it('never puts one highlight inside the tags of another', () => {
      expect(highlightText('remark', 'mark ma')).toBe('re<mark>mark</mark>');
    });
  });

  describe('toTitleCase()', () => {
    it('should convert to title case', () => {
      expect(toTitleCase('hello world')).toBe('Hello World');
    });

    it('should handle hyphens', () => {
      expect(toTitleCase('test-case')).toBe('Test Case');
    });

    it('should handle underscores', () => {
      expect(toTitleCase('test_case')).toBe('Test Case');
    });

    it('should handle mixed separators', () => {
      expect(toTitleCase('test-case_name')).toBe('Test Case Name');
    });

    it('should handle empty/null', () => {
      expect(toTitleCase('')).toBe('');
      expect(toTitleCase(null)).toBe('');
    });

    it('should handle numbers', () => {
      expect(toTitleCase(123)).toBe('123');
    });
  });

  describe('formatType()', () => {
    it('should format post type', () => {
      expect(formatType('post')).toBe('Tutorial & Blog');
    });

    it('should format project type', () => {
      expect(formatType('project')).toBe('Project');
    });

    it('should format research type', () => {
      expect(formatType('research')).toBe('Research');
    });

    it('should format dataset type', () => {
      expect(formatType('dataset')).toBe('Dataset');
    });

    it('should convert unknown types to title case', () => {
      expect(formatType('custom-type')).toBe('Custom Type');
    });

    it('should handle empty type', () => {
      expect(formatType('')).toBe('Page');
      expect(formatType(null)).toBe('Page');
    });
  });
});
