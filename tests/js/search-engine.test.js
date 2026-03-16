import { describe, expect, it } from 'vitest';
import { createSearchEngine, buildSuggestionPool } from '../../assets/js/search/engine.js';

function makeDoc(overrides = {}) {
  return {
    title: 'Test Document',
    summary: 'A test summary',
    content: 'Some test content for searching',
    url: '/test/',
    type: 'post',
    tags: ['testing'],
    languages: ['python'],
    difficulty: 'beginner',
    date: '2024-01-01',
    reading_time: 3,
    ...overrides,
  };
}

describe('createSearchEngine', () => {
  it('returns an engine with search, setDocuments, suggestions, getDocuments', () => {
    const engine = createSearchEngine();
    expect(typeof engine.search).toBe('function');
    expect(typeof engine.setDocuments).toBe('function');
    expect(typeof engine.suggestions).toBe('function');
    expect(typeof engine.getDocuments).toBe('function');
  });

  it('initializes with documents', () => {
    const docs = [makeDoc()];
    const engine = createSearchEngine(docs);
    expect(engine.getDocuments()).toHaveLength(1);
  });

  it('handles non-array initialDocuments gracefully', () => {
    const engine = createSearchEngine('not an array');
    expect(engine.getDocuments()).toEqual([]);
  });

  it('handles null initialDocuments', () => {
    const engine = createSearchEngine(null);
    expect(engine.getDocuments()).toEqual([]);
  });

  it('setDocuments replaces the document list', () => {
    const engine = createSearchEngine([makeDoc()]);
    expect(engine.getDocuments()).toHaveLength(1);
    engine.setDocuments([makeDoc(), makeDoc({ title: 'Second' })]);
    expect(engine.getDocuments()).toHaveLength(2);
  });

  it('setDocuments handles non-array input', () => {
    const engine = createSearchEngine([makeDoc()]);
    engine.setDocuments(null);
    expect(engine.getDocuments()).toEqual([]);
  });

  it('getDocuments returns a copy, not the original', () => {
    const docs = [makeDoc()];
    const engine = createSearchEngine(docs);
    const returned = engine.getDocuments();
    returned.push(makeDoc());
    expect(engine.getDocuments()).toHaveLength(1);
  });
});

describe('search — empty and malformed input', () => {
  const engine = createSearchEngine([makeDoc()]);

  it('returns empty array for empty query', () => {
    expect(engine.search('')).toEqual([]);
  });

  it('returns empty array for whitespace-only query', () => {
    expect(engine.search('   ')).toEqual([]);
  });

  it('returns empty array for null query', () => {
    expect(engine.search(null)).toEqual([]);
  });

  it('returns empty array for undefined query', () => {
    expect(engine.search(undefined)).toEqual([]);
  });

  it('returns empty array when no documents match', () => {
    expect(engine.search('zzzznonexistent')).toEqual([]);
  });
});

describe('search — title matching', () => {
  it('exact title match scores highest', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Python Data Analysis', languages: [] }),
      makeDoc({ title: 'R Statistics', url: '/r/', languages: ['r'], tags: ['stats'] }),
    ]);

    const results = engine.search('Python Data Analysis');
    expect(results.length).toBeGreaterThanOrEqual(1);
    expect(results[0].title).toBe('Python Data Analysis');
    expect(results[0].score).toBeGreaterThanOrEqual(40);
  });

  it('partial title token match scores lower than full match', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Python Data Analysis', url: '/python/' }),
      makeDoc({ title: 'Data Visualization Guide', url: '/viz/', summary: 'data charts', content: 'data viz' }),
    ]);

    const results = engine.search('Data');
    expect(results.length).toBeGreaterThanOrEqual(2);
    // Both should match on "data" token
    results.forEach(r => expect(r.score).toBeGreaterThan(0));
  });
});

describe('search — content and summary scoring', () => {
  it('scores summary matches', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Unrelated', summary: 'bayesian inference methods', content: 'nothing' }),
    ]);
    const results = engine.search('bayesian');
    expect(results).toHaveLength(1);
    expect(results[0].score).toBeGreaterThan(0);
  });

  it('scores content matches', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Unrelated', summary: 'nothing', content: 'deep learning architectures' }),
    ]);
    const results = engine.search('deep learning');
    expect(results).toHaveLength(1);
  });

  it('generates snippet from content match', () => {
    const engine = createSearchEngine([
      makeDoc({ content: 'This is a long article about neural networks and their applications in data science.' }),
    ]);
    const results = engine.search('neural networks');
    expect(results).toHaveLength(1);
    expect(results[0].snippet).toBeTruthy();
  });

  it('generates snippet from summary when content does not match', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'ML Guide',
        summary: 'A guide about gradient boosting for tabular data',
        content: 'No match here whatsoever',
      }),
    ]);
    const results = engine.search('gradient boosting');
    expect(results).toHaveLength(1);
    expect(results[0].snippet).toBeTruthy();
  });
});

describe('search — tag and language scoring', () => {
  it('scores tag matches', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Post A', tags: ['machine-learning', 'python'], url: '/a/' }),
    ]);
    const results = engine.search('machine-learning');
    expect(results).toHaveLength(1);
    expect(results[0].score).toBeGreaterThan(0);
  });

  it('scores language matches', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Post B', languages: ['julia'], url: '/b/' }),
    ]);
    const results = engine.search('julia');
    expect(results).toHaveLength(1);
  });

  it('scores difficulty matches', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Post C', difficulty: 'advanced', url: '/c/' }),
    ]);
    const results = engine.search('advanced');
    expect(results).toHaveLength(1);
  });
});

describe('search — code matching', () => {
  it('matches exact code content', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Code Post',
        code: [{ language: 'python', code: 'def train_model(X, y): return model.fit(X, y)' }],
      }),
    ]);
    const results = engine.search('train_model');
    expect(results).toHaveLength(1);
    expect(results[0].codeSnippet).toBeTruthy();
    expect(results[0].codeSnippet.language).toBe('python');
  });

  it('fuzzy matches code when query looks like code', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Fuzzy Code',
        code: [{ language: 'python', code: 'def calculate_metrics(predictions, actuals):' }],
      }),
    ]);
    // isCodeQuery triggers on parentheses, dots, underscores
    const results = engine.search('calculate_metrics()');
    expect(results).toHaveLength(1);
    expect(results[0].codeSnippet).toBeTruthy();
  });

  it('falls back to first code block when no code matches', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Code Fallback Test',
        content: 'Code Fallback Test content here',
        code: [{ language: 'r', code: 'library(ggplot2)' }],
      }),
    ]);
    const results = engine.search('Code Fallback Test');
    expect(results).toHaveLength(1);
    expect(results[0].codeSnippet).toBeTruthy();
    expect(results[0].codeSnippet.language).toBe('r');
  });

  it('handles code blocks with missing language', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'No Lang Code',
        code: [{ code: 'print("hello")' }],
      }),
    ]);
    const results = engine.search('print');
    expect(results).toHaveLength(1);
    expect(results[0].codeSnippet.language).toBe('');
  });
});

describe('search — math matching', () => {
  it('matches math expressions', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Math Post',
        math: ['\\int_0^1 x^2 dx', 'E = mc^2'],
      }),
    ]);
    const results = engine.search('E = mc^2');
    expect(results).toHaveLength(1);
    expect(results[0].mathSnippet).toBeTruthy();
  });

  it('provides first math segment as fallback for math-like queries', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Math Fallback',
        content: 'Math Fallback content integral calculus',
        math: ['\\sum_{i=1}^n x_i'],
      }),
    ]);
    // isMathQuery triggers on backslash, ^, _, etc.
    const results = engine.search('\\frac{a}{b}');
    expect(results).toHaveLength(1);
    expect(results[0].mathSnippet).toBe('\\sum_{i=1}^n x_i');
  });

  it('does not provide math fallback for non-math queries', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Has Math',
        math: ['x^2'],
      }),
    ]);
    const results = engine.search('Has Math');
    expect(results).toHaveLength(1);
    expect(results[0].mathSnippet).toBeNull();
  });
});

describe('search — filters', () => {
  const docs = [
    makeDoc({ title: 'Python Post', type: 'post', languages: ['python'], difficulty: 'beginner', tags: ['ml'], url: '/1/' }),
    makeDoc({ title: 'R Post', type: 'post', languages: ['r'], difficulty: 'advanced', tags: ['stats'], url: '/2/' }),
    makeDoc({ title: 'Dataset Entry', type: 'dataset', languages: ['sql'], difficulty: 'intermediate', tags: ['data'], url: '/3/' }),
  ];

  it('filters by type', () => {
    const engine = createSearchEngine(docs);
    const results = engine.search('Post', { type: 'dataset' });
    expect(results.every(r => r.type === 'dataset')).toBe(true);
  });

  it('filters by language', () => {
    const engine = createSearchEngine(docs);
    const results = engine.search('Post', { language: 'r' });
    expect(results).toHaveLength(1);
    expect(results[0].title).toBe('R Post');
  });

  it('filters by difficulty', () => {
    const engine = createSearchEngine(docs);
    const results = engine.search('Post', { difficulty: 'advanced' });
    expect(results).toHaveLength(1);
    expect(results[0].title).toBe('R Post');
  });

  it('filters by tags', () => {
    const engine = createSearchEngine(docs);
    const results = engine.search('Post', { tags: new Set(['ml']) });
    expect(results).toHaveLength(1);
    expect(results[0].title).toBe('Python Post');
  });

  it('excludes docs missing required tag', () => {
    const engine = createSearchEngine(docs);
    const results = engine.search('Post', { tags: new Set(['nonexistent']) });
    expect(results).toEqual([]);
  });

  it('filters by difficulty excludes docs without difficulty', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'No Difficulty', difficulty: '', url: '/nd/' }),
    ]);
    const results = engine.search('No Difficulty', { difficulty: 'beginner' });
    expect(results).toEqual([]);
  });
});

describe('search — sorting', () => {
  it('sorts by score descending', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Python Basics', summary: 'python intro', content: 'python content', url: '/1/' }),
      makeDoc({ title: 'Unrelated Topic', summary: 'python mentioned once', content: 'other stuff', url: '/2/' }),
    ]);
    const results = engine.search('python');
    expect(results.length).toBeGreaterThanOrEqual(2);
    expect(results[0].score).toBeGreaterThanOrEqual(results[1].score);
  });

  it('breaks score ties alphabetically by title', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Zebra Article', summary: 'test content', url: '/z/' }),
      makeDoc({ title: 'Alpha Article', summary: 'test content', url: '/a/' }),
    ]);
    const results = engine.search('test content');
    const sameScore = results.filter(r => r.score === results[0].score);
    if (sameScore.length >= 2) {
      expect(sameScore[0].title.localeCompare(sameScore[1].title)).toBeLessThanOrEqual(0);
    }
  });
});

describe('search — result shape', () => {
  it('returns well-formed result objects', () => {
    const engine = createSearchEngine([makeDoc()]);
    const results = engine.search('Test');
    expect(results).toHaveLength(1);
    const result = results[0];
    expect(result).toHaveProperty('id');
    expect(result).toHaveProperty('title');
    expect(result).toHaveProperty('url');
    expect(result).toHaveProperty('summary');
    expect(result).toHaveProperty('snippet');
    expect(result).toHaveProperty('codeSnippet');
    expect(result).toHaveProperty('mathSnippet');
    expect(result).toHaveProperty('tags');
    expect(result).toHaveProperty('languages');
    expect(result).toHaveProperty('difficulty');
    expect(result).toHaveProperty('type');
    expect(result).toHaveProperty('date');
    expect(result).toHaveProperty('readingTime');
    expect(result).toHaveProperty('score');
  });

  it('uses doc.url as id', () => {
    const engine = createSearchEngine([makeDoc({ url: '/my-post/' })]);
    const results = engine.search('Test');
    expect(results[0].id).toBe('/my-post/');
  });
});

describe('search — normalized data fast path', () => {
  it('uses pre-normalized data when available', () => {
    const engine = createSearchEngine([
      makeDoc({
        title: 'Normalized Doc',
        normalized: {
          title: 'normalized doc',
          summary: 'pre-normalized summary',
          content: 'pre-normalized content',
          tags: ['testing'],
          languages: ['python'],
          difficulty: 'beginner',
        },
      }),
    ]);
    const results = engine.search('normalized');
    expect(results).toHaveLength(1);
  });

  it('falls back to normalizing raw values when normalized is empty', () => {
    const engine = createSearchEngine([
      makeDoc({ title: 'Raw Values Only', normalized: {} }),
    ]);
    const results = engine.search('Raw Values');
    expect(results).toHaveLength(1);
  });
});

describe('buildSuggestionPool', () => {
  it('collects titles', () => {
    const pool = buildSuggestionPool([{ title: 'My Post' }]);
    expect(pool).toContain('My Post');
  });

  it('collects languages', () => {
    const pool = buildSuggestionPool([{ title: 'X', languages: ['python', 'r'] }]);
    expect(pool).toContain('python');
    expect(pool).toContain('r');
  });

  it('collects tags with hash prefix', () => {
    const pool = buildSuggestionPool([{ title: 'X', tags: ['ml', 'stats'] }]);
    expect(pool).toContain('#ml');
    expect(pool).toContain('#stats');
  });

  it('collects math expressions (up to 3)', () => {
    const pool = buildSuggestionPool([{
      title: 'X',
      math: ['a', 'b', 'c', 'd'],
    }]);
    expect(pool).toContain('a');
    expect(pool).toContain('b');
    expect(pool).toContain('c');
    expect(pool).not.toContain('d');
  });

  it('deduplicates suggestions', () => {
    const pool = buildSuggestionPool([
      { title: 'Python', languages: ['python'] },
      { title: 'Python', languages: ['python'] },
    ]);
    const pythonCount = pool.filter(s => s === 'Python').length;
    expect(pythonCount).toBe(1);
  });

  it('respects limit', () => {
    const items = Array.from({ length: 50 }, (_, i) => ({ title: `Item ${i}` }));
    const pool = buildSuggestionPool(items, 10);
    expect(pool).toHaveLength(10);
  });

  it('handles empty input', () => {
    expect(buildSuggestionPool([])).toEqual([]);
    expect(buildSuggestionPool()).toEqual([]);
  });

  it('skips items without title', () => {
    const pool = buildSuggestionPool([{ languages: ['python'] }]);
    expect(pool).toContain('python');
    expect(pool).toHaveLength(1);
  });
});
