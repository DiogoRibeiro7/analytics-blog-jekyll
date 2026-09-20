import { beforeEach, describe, expect, it, vi } from 'vitest';

import { CONTEXT, describeRange, locate, sectionOf, textIndex } from '../../assets/js/reading-state/anchors.js';
import { MARK_CLASS, clearMarks, paint, wrapRange } from '../../assets/js/reading-state/highlights.js';
import { measure, worthResuming } from '../../assets/js/reading-state/progress.js';
import { PREFIX, browserStorage, createStore, emptyRecord } from '../../assets/js/reading-state/storage.js';
import { initArticle, initBookmark, initReadingList, initReadingState } from '../../assets/js/reading-state/ui.js';

/**
 * Local reading state (#260): storage with and without a browser that
 * allows it, text anchors that survive edits, highlights painted as marks
 * (jsdom has no Custom Highlight API), progress, and the controls.
 */

function fakeStorage() {
  const map = new Map();
  return {
    get length() {
      return map.size;
    },
    key: (index) => Array.from(map.keys())[index] ?? null,
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: (key) => map.delete(key),
    map,
  };
}

function throwingStorage() {
  const blocked = () => {
    throw new Error('blocked');
  };
  return { get length() { return blocked(); }, key: blocked, getItem: blocked, setItem: blocked, removeItem: blocked };
}

const ARTICLE = '/2026/01/01/paper/';

function rangeOver(root, text, occurrence = 0) {
  const index = textIndex(root);
  let at = -1;
  for (let count = 0; count <= occurrence; count += 1) {
    at = index.text.indexOf(text, at + 1);
  }
  const start = index.nodes.find((entry) => at >= entry.start && at < entry.end);
  const endAt = at + text.length;
  const end = index.nodes.find((entry) => endAt > entry.start && endAt <= entry.end);
  const range = document.createRange();
  range.setStart(start.node, at - start.start);
  range.setEnd(end.node, endAt - end.start);
  return range;
}

const PANEL = `
<div data-reading-state data-article="${ARTICLE}" data-title="Paper" data-progress="true" data-highlights="true">
  <div data-reading-resume data-progress-label="{{percent}}% read" hidden>
    <span data-reading-resume-detail></span>
    <button type="button" data-reading-resume-go>Resume</button>
    <button type="button" data-reading-resume-dismiss>Dismiss</button>
  </div>
  <div data-reading-toolbar hidden><button type="button" data-reading-highlight>Highlight</button><button type="button" data-reading-note>Note</button></div>
  <section data-reading-panel>
    <p data-reading-unavailable hidden>Storage is off.</p>
    <p data-reading-empty>Nothing yet.</p>
    <ul data-reading-list-items></ul>
    <template data-reading-item-template>
      <li data-annotation>
        <blockquote data-annotation-quote></blockquote>
        <p><span data-annotation-section></span> <span data-annotation-lost hidden>Lost</span></p>
        <textarea data-annotation-note></textarea>
        <button type="button" data-annotation-go>Go</button>
        <button type="button" data-annotation-remove>Remove</button>
      </li>
    </template>
    <button type="button" data-reading-export data-done="Exported">Export</button>
    <input type="file" data-reading-import data-done="{{count}} imported" data-failed="Bad file">
    <button type="button" data-reading-erase-article data-done="Article erased">Erase article</button>
    <button type="button" data-reading-erase-all data-done="All erased">Erase all</button>
    <p data-reading-status></p>
  </section>
</div>`;

const BOOKMARK = `<button type="button" data-bookmark-toggle aria-pressed="false" data-article="${ARTICLE}" data-title="Paper"
  data-label-save="Save for later" data-label-saved="Saved" data-unavailable="No storage"><span data-bookmark-label>Save for later</span></button>`;

const CONTENT = `
<div class="post-content">
  <h2 id="intro">Introduction</h2>
  <p>The quick brown fox jumps over the lazy dog. The quick brown fox again.</p>
  <h2 id="method">Method</h2>
  <p>We fit a <em>mixed</em> model to the data and report the estimates.</p>
</div>`;

function mount(html) {
  document.body.innerHTML = html;
  return document.body;
}

describe('storage', () => {
  it('keeps one record per article and lists, exports, imports and erases them', () => {
    const store = createStore(fakeStorage());

    expect(store.available).toBe(true);
    expect(store.read(ARTICLE)).toBeNull();
    expect(store.write(ARTICLE, { ...emptyRecord(ARTICLE, 'Paper'), bookmarked: true })).toBe(true);
    expect(store.write('/other/', { annotations: [{ id: 'a', quote: 'q' }, { quote: 'no id' }] })).toBe(true);

    expect(store.read(ARTICLE)).toMatchObject({ article: ARTICLE, title: 'Paper', bookmarked: true, annotations: [] });
    expect(store.read(ARTICLE).updated_at).toMatch(/^\d{4}-/);
    expect(store.read('/other/').annotations).toEqual([{ id: 'a', quote: 'q' }]);
    expect(store.all().map((record) => record.article).sort()).toEqual([ARTICLE, '/other/']);

    const exported = JSON.parse(store.exportJSON());
    expect(exported.format).toBe(1);
    expect(exported.articles).toHaveLength(2);

    expect(store.clear()).toBe(true);
    expect(store.all()).toEqual([]);
    expect(store.importJSON(JSON.stringify(exported))).toBe(2);
    expect(store.read(ARTICLE).bookmarked).toBe(true);
    expect(() => store.importJSON('{"nope": 1}')).toThrow(/export/);
    expect(store.remove('/other/')).toBe(true);
    expect(store.all()).toHaveLength(1);
  });

  it('does nothing, without errors, when the browser gives no storage', () => {
    const store = createStore(null);

    expect(store.available).toBe(false);
    expect(store.write(ARTICLE, emptyRecord(ARTICLE))).toBe(false);
    expect(store.read(ARTICLE)).toBeNull();
    expect(store.all()).toEqual([]);
    expect(store.clear()).toBe(false);

    const broken = createStore(throwingStorage());
    expect(broken.write(ARTICLE, emptyRecord(ARTICLE))).toBe(false);
    expect(broken.all()).toEqual([]);
  });

  it('probes localStorage and answers null when the browser throws', () => {
    expect(browserStorage(window)).toBe(window.localStorage);
    expect(browserStorage({ get localStorage() { throw new Error('blocked'); } })).toBeNull();
    expect(window.localStorage.getItem(`${PREFIX}probe`)).toBeNull();
  });
});

describe('anchors', () => {
  beforeEach(() => mount(CONTENT));

  it('describes a range as its quote with context and section', () => {
    const root = document.querySelector('.post-content');
    const anchor = describeRange(rangeOver(root, 'mixed model'), root);

    expect(anchor.quote).toBe('mixed model');
    expect(anchor.prefix).toMatch(/We fit a $/);
    expect(anchor.prefix).toHaveLength(CONTEXT);
    expect(anchor.suffix.startsWith(' to the data')).toBe(true);
    expect(anchor.section).toBe('method');
    expect(sectionOf(root, root.querySelector('p'))).toBe('intro');
    expect(CONTEXT).toBe(32);
  });

  it('finds the quote again, by context when it appears more than once', () => {
    const root = document.querySelector('.post-content');
    const second = describeRange(rangeOver(root, 'quick brown fox', 1), root);

    expect(locate(root, second).toString()).toBe('quick brown fox');
    expect(locate(root, second).startOffset).toBe(rangeOver(root, 'quick brown fox', 1).startOffset);
    expect(locate(root, { quote: 'quick brown fox', prefix: 'The ', suffix: ' jumps' }).startOffset).toBe(4);
  });

  it('survives edits around the passage and reports a passage that is gone', () => {
    const root = document.querySelector('.post-content');
    const anchor = describeRange(rangeOver(root, 'report the estimates'), root);

    root.querySelector('#method + p').innerHTML = 'After a rewrite we now report the estimates with intervals.';
    expect(locate(root, anchor).toString()).toBe('report the estimates');

    root.querySelector('#method + p').innerHTML = 'We  now\nreport   the estimates.';
    expect(locate(root, anchor).toString()).toBe('report   the estimates');

    root.querySelector('#method + p').innerHTML = 'Something else entirely.';
    expect(locate(root, anchor)).toBeNull();
    expect(locate(root, { quote: '' })).toBeNull();
  });
});

describe('highlights', () => {
  beforeEach(() => mount(CONTENT));

  it('wraps a range in marks and clears them without changing the text', () => {
    const root = document.querySelector('.post-content');
    const before = root.textContent;
    const across = document.createRange();
    across.setStart(root.querySelector('#method + p').firstChild, 3);
    across.setEnd(root.querySelector('em').firstChild, 3);
    wrapRange(across, 'x');

    const marks = root.querySelectorAll(`mark.${MARK_CLASS}`);
    expect(marks).toHaveLength(2);
    expect(Array.from(marks).map((mark) => mark.textContent)).toEqual(['fit a ', 'mix']);
    expect(root.textContent).toBe(before);

    clearMarks(root);
    expect(root.querySelector('mark')).toBeNull();
    expect(root.querySelector('#method + p').childNodes).toHaveLength(3);
  });

  it('paints what it finds and reports what it cannot', () => {
    const root = document.querySelector('.post-content');
    const result = paint(root, [
      { id: 'a', quote: 'lazy dog', prefix: 'over the ', suffix: '. The' },
      { id: 'gone', quote: 'not in the text' },
      { id: 'b', quote: 'mixed', prefix: 'We fit a ', suffix: ' model' },
    ], { api: false });

    expect(result).toEqual({ found: ['a', 'b'], lost: ['gone'] });
    expect(Array.from(root.querySelectorAll('mark')).map((mark) => mark.dataset.annotationId)).toEqual(['a', 'b']);
  });

  it('uses the Custom Highlight API when the window has it', () => {
    const root = document.querySelector('.post-content');
    const set = new Map();
    const Highlight = vi.fn(function fakeHighlight(...ranges) {
      this.size = ranges.length;
    });
    const win = root.ownerDocument.defaultView;
    win.CSS = { highlights: set };
    win.Highlight = Highlight;

    paint(root, [{ id: 'a', quote: 'lazy dog' }]);

    expect(root.querySelector('mark')).toBeNull();
    expect(set.get('datalog-annotation').size).toBe(1);
    delete win.CSS;
    delete win.Highlight;
  });
});

describe('progress', () => {
  it('measures the position as a ratio and the nearest heading', () => {
    const headings = [{ id: 'intro', top: 100 }, { id: 'method', top: 1500 }];
    const view = { innerHeight: 1000, contentTop: 100, contentHeight: 3000, headings };

    expect(measure({ ...view, scrollY: 0 })).toEqual({ ratio: 0.1, anchor: 'intro' });
    expect(measure({ ...view, scrollY: 1400 })).toEqual({ ratio: 0.567, anchor: 'method' });
    expect(measure({ ...view, scrollY: 9000 })).toEqual({ ratio: 1, anchor: 'method' });
    expect(measure({ ...view, contentHeight: 0, scrollY: 0 }).ratio).toBe(0);
  });

  it('offers to resume only some way into a long article', () => {
    expect(worthResuming({ ratio: 0.5 }, 3000, 800)).toBe(true);
    expect(worthResuming({ ratio: 0.02 }, 3000, 800)).toBe(false);
    expect(worthResuming({ ratio: 0.97 }, 3000, 800)).toBe(false);
    expect(worthResuming({ ratio: 0.5 }, 900, 800)).toBe(false);
    expect(worthResuming(undefined, 3000, 800)).toBe(false);
  });
});

describe('controls', () => {
  let storage;

  beforeEach(() => {
    storage = fakeStorage();
    mount(`${BOOKMARK}${CONTENT}${PANEL}`);
  });

  it('bookmarks an article and keeps it across visits', () => {
    const button = document.querySelector('[data-bookmark-toggle]');
    initBookmark(button, createStore(storage));

    button.click();
    expect(button.getAttribute('aria-pressed')).toBe('true');
    expect(button.textContent).toBe('Saved');
    expect(createStore(storage).read(ARTICLE).bookmarked).toBe(true);

    const revisited = mount(BOOKMARK).querySelector('[data-bookmark-toggle]');
    initBookmark(revisited, createStore(storage));
    expect(revisited.getAttribute('aria-pressed')).toBe('true');
    revisited.click();
    expect(createStore(storage).read(ARTICLE).bookmarked).toBe(false);
  });

  it('saves a highlight of a range, lists it with its note, and removes it', () => {
    const root = document.querySelector('.post-content');
    const controller = initArticle(document.querySelector('[data-reading-state]'), createStore(storage));

    const annotation = controller.addAnnotation(rangeOver(root, 'lazy dog'), 'check');
    expect(annotation).toMatchObject({ quote: 'lazy dog', section: 'intro', note: 'check' });
    expect(annotation.prefix).toMatch(/over the $/);
    expect(annotation.prefix).toHaveLength(CONTEXT);
    expect(root.querySelectorAll('mark')).toHaveLength(1);

    const item = document.querySelector('[data-annotation]');
    expect(item.querySelector('[data-annotation-quote]').textContent).toBe('lazy dog');
    expect(item.querySelector('[data-annotation-section]').textContent).toBe('Introduction');
    expect(item.querySelector('[data-annotation-note]').value).toBe('check');
    expect(document.querySelector('[data-reading-empty]').hidden).toBe(true);

    const note = item.querySelector('[data-annotation-note]');
    note.value = 'checked';
    note.dispatchEvent(new Event('change'));
    expect(createStore(storage).read(ARTICLE).annotations[0].note).toBe('checked');

    item.querySelector('[data-annotation-remove]').click();
    expect(root.querySelector('mark')).toBeNull();
    expect(document.querySelector('[data-annotation]')).toBeNull();
    expect(document.querySelector('[data-reading-empty]').hidden).toBe(false);
    expect(createStore(storage).read(ARTICLE).annotations).toEqual([]);
  });

  it('highlights the current selection from the toolbar and the shortcut', () => {
    const root = document.querySelector('.post-content');
    const controller = initArticle(document.querySelector('[data-reading-state]'), createStore(storage));
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(rangeOver(root, 'mixed model'));

    expect(controller.highlightSelection()).toMatchObject({ quote: 'mixed model' });
    expect(root.querySelector('mark').textContent).toBe('mixed');

    selection.removeAllRanges();
    selection.addRange(rangeOver(root, 'lazy dog'));
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'H', altKey: true, shiftKey: true }));
    expect(createStore(storage).read(ARTICLE).annotations.map((entry) => entry.quote)).toEqual(['mixed model', 'lazy dog']);
    expect(controller.highlightSelection()).toBeNull();
  });

  it('keeps a highlight after the article changes around it and flags one that is gone', () => {
    const root = document.querySelector('.post-content');
    const store = createStore(storage);
    let controller = initArticle(document.querySelector('[data-reading-state]'), store);
    controller.addAnnotation(rangeOver(root, 'report the estimates'));
    controller.addAnnotation(rangeOver(root, 'lazy dog'));

    root.querySelector('#method + p').innerHTML = 'Revised: we report the estimates below.';
    root.querySelector('#intro + p').innerHTML = 'The quick brown fox jumps over the sleepy cat.';
    mount(`${BOOKMARK}${root.outerHTML}${PANEL}`);
    controller = initArticle(document.querySelector('[data-reading-state]'), store);

    expect(Array.from(document.querySelectorAll('mark')).map((mark) => mark.textContent)).toEqual(['report the estimates']);
    const items = document.querySelectorAll('[data-annotation]');
    expect(items[0].querySelector('[data-annotation-lost]').hidden).toBe(true);
    expect(items[1].querySelector('[data-annotation-lost]').hidden).toBe(false);
    expect(controller.removeAnnotation('missing')).toBe(false);
  });

  it('offers to resume a long article and scrolls to the saved heading', () => {
    const root = document.querySelector('.post-content');
    const store = createStore(storage);
    store.write(ARTICLE, { ...emptyRecord(ARTICLE), progress: { ratio: 0.5, anchor: 'method' } });
    root.getBoundingClientRect = () => ({ top: 0, height: 5000 });
    const heading = document.getElementById('method');
    heading.scrollIntoView = vi.fn();

    initArticle(document.querySelector('[data-reading-state]'), store);
    const resume = document.querySelector('[data-reading-resume]');

    expect(resume.hidden).toBe(false);
    expect(resume.querySelector('[data-reading-resume-detail]').textContent).toBe('Method · 50% read');
    resume.querySelector('[data-reading-resume-go]').click();
    expect(heading.scrollIntoView).toHaveBeenCalledWith({ block: 'start' });
    expect(resume.hidden).toBe(true);
  });

  it('exports, erases and reports through the data controls', () => {
    const store = createStore(storage);
    const controller = initArticle(document.querySelector('[data-reading-state]'), store);
    controller.addAnnotation(rangeOver(document.querySelector('.post-content'), 'lazy dog'));
    window.URL.createObjectURL = vi.fn(() => 'blob:x');
    window.URL.revokeObjectURL = vi.fn();
    window.confirm = vi.fn(() => true);

    document.querySelector('[data-reading-export]').click();
    expect(window.URL.createObjectURL).toHaveBeenCalled();
    expect(document.querySelector('[data-reading-status]').textContent).toBe('Exported');

    document.querySelector('[data-reading-erase-article]').click();
    expect(store.read(ARTICLE)).toBeNull();
    expect(document.querySelector('mark')).toBeNull();

    store.write('/other/', { ...emptyRecord('/other/'), bookmarked: true });
    document.querySelector('[data-reading-erase-all]').click();
    expect(store.all()).toEqual([]);
    expect(document.querySelector('[data-reading-status]').textContent).toBe('All erased');
  });

  it('disables everything and says so when the browser gives no storage', () => {
    const store = createStore(null);
    const result = initReadingState(document, store);

    expect(result.article.available).toBe(false);
    expect(document.querySelector('[data-reading-unavailable]').hidden).toBe(false);
    expect(document.querySelector('[data-bookmark-toggle]').disabled).toBe(true);
    expect(document.querySelector('[data-bookmark-toggle]').title).toBe('No storage');
    expect(document.querySelector('[data-reading-export]').disabled).toBe(true);
    expect(result.article.addAnnotation()).toBeNull();
  });

  it('lists the saved articles on a page', () => {
    mount(`<div data-reading-list data-progress-label="{{percent}}% read" data-highlights-label="{{count}} highlights"
      data-saved-label="Saved" data-remove-label="Remove"><p data-reading-list-empty>None</p><ul data-reading-list-items></ul></div>`);
    const store = createStore(storage);
    store.write(ARTICLE, { ...emptyRecord(ARTICLE, 'Paper'), bookmarked: true, progress: { ratio: 0.63, anchor: null },
      annotations: [{ id: 'a', quote: 'q' }, { id: 'b', quote: 'r' }] });
    store.write('/read/', { ...emptyRecord('/read/', 'Read'), progress: { ratio: 0.2 } });
    store.write('/nothing/', emptyRecord('/nothing/', 'Nothing'));

    const list = initReadingList(document.querySelector('[data-reading-list]'), store);
    const items = document.querySelectorAll('[data-reading-list-items] li');

    expect(items).toHaveLength(2);
    const byTitle = (title) => Array.from(items).find((item) => item.querySelector('a').textContent === title);
    expect(byTitle('Read').querySelector('.reading-list__meta').textContent).toBe('20% read');
    expect(byTitle('Paper').querySelector('.reading-list__meta').textContent).toBe('Saved · 63% read · 2 highlights');
    expect(document.querySelector('[data-reading-list-empty]').hidden).toBe(true);

    byTitle('Paper').querySelector('button').click();
    expect(store.read(ARTICLE)).toBeNull();
    list.render();
    expect(document.querySelectorAll('[data-reading-list-items] li')).toHaveLength(1);
  });
});

describe('patch regressions', () => {
  it('keeps readable full storage available and reports failed saves without losing the selection', () => {
    const storage = fakeStorage();
    storage.setItem = () => { throw new DOMException('full', 'QuotaExceededError'); };
    expect(browserStorage({ localStorage: storage })).toBe(storage);
    mount(`${BOOKMARK}${CONTENT}${PANEL}`);
    const store = createStore(storage);
    const controller = initReadingState(document, store).article;
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(rangeOver(document.querySelector('.post-content'), 'lazy dog'));
    expect(controller.highlightSelection()).toBeNull();
    expect(selection.toString()).toBe('lazy dog');
    expect(document.querySelector('[data-reading-status]').textContent).not.toBe('');
    expect(document.querySelector('[data-reading-erase-all]').disabled).toBe(false);
    document.querySelector('[data-bookmark-toggle]').click();
    expect(document.querySelector('[data-bookmark-toggle]').getAttribute('aria-pressed')).toBe('false');
    document.querySelector('[data-reading-erase-article]').click();
  });

  it('merges and sanitizes imported records', () => {
    const store = createStore(fakeStorage());
    store.write(ARTICLE, { bookmarked: true, annotations: [{ id: 'local', quote: 'keep' }] });
    store.importJSON(JSON.stringify({ articles: [{ article: ARTICLE, progress: { ratio: 7, anchor: 42, secret: 'drop' },
      annotations: [{ id: 'other', quote: 'old' }, { id: 'other', quote: 'new', note: {}, prefix: [], secret: 'drop' }] }] }));
    expect(store.read(ARTICLE).bookmarked).toBe(true);
    expect(store.read(ARTICLE).progress).toEqual({ ratio: 1, anchor: null });
    expect(store.read(ARTICLE).annotations).toEqual([{ id: 'local', quote: 'keep' }, { id: 'other', quote: 'new' }]);
  });

  it('preserves the resume position until dismissed and does not recreate erased data', () => {
    vi.useFakeTimers();
    mount(CONTENT + PANEL);
    const store = createStore(fakeStorage());
    store.write(ARTICLE, { progress: { ratio: 0.8, anchor: 'method' } });
    document.querySelector('.post-content').getBoundingClientRect = () => ({ top: 0, height: 5000 });
    initArticle(document.querySelector('[data-reading-state]'), store);
    window.dispatchEvent(new Event('scroll'));
    vi.advanceTimersByTime(1100);
    expect(store.read(ARTICLE).progress.ratio).toBe(0.8);
    document.querySelector('[data-reading-resume-dismiss]').click();
    window.dispatchEvent(new Event('scroll'));
    window.dispatchEvent(new Event('pagehide'));
    expect(store.read(ARTICLE).progress.ratio).toBeLessThan(0.8);
    document.querySelector('[data-reading-erase-article]').click();
    window.dispatchEvent(new Event('scroll'));
    vi.advanceTimersByTime(1100);
    window.dispatchEvent(new Event('pagehide'));
    expect(store.read(ARTICLE)).toBeNull();
  });

  it('repaints highlights after math and lazy visualization rendering', () => {
    mount('<div class="post-content"><p>variance \\(sigma^2\\) of the estimator</p></div>' + PANEL);
    const store = createStore(fakeStorage());
    store.write(ARTICLE, { annotations: [{ id: 'math', quote: 'variance σ2 of the estimator' }, { id: 'chart', quote: 'Chart caption' }] });
    initArticle(document.querySelector('[data-reading-state]'), store);
    expect(document.querySelector('[data-annotation-lost]').hidden).toBe(false);
    document.querySelector('.post-content').innerHTML = '<p>variance <mjx-container><mjx-assistive-mml>σ2</mjx-assistive-mml></mjx-container> of the estimator</p>';
    document.dispatchEvent(new CustomEvent('datalog:math-ready'));
    expect(document.querySelector('[data-annotation-lost]').hidden).toBe(true);
    document.querySelector('.post-content').insertAdjacentHTML('beforeend', '<p>Chart caption</p>');
    document.dispatchEvent(new CustomEvent('datalog:viz-rendered'));
    expect([...document.querySelectorAll('[data-annotation-lost]')].every((node) => node.hidden)).toBe(true);
  });

  it('does not relocate deleted passages to other sections or guess between identical matches', () => {
    mount('<div class="post-content"><h2 id="bias">Bias</h2><p>Use a robust estimator here.</p><h2 id="cost">Cost</h2><p>Use a robust estimator here.</p></div>');
    const root = document.querySelector('.post-content');
    const anchor = describeRange(rangeOver(root, 'robust estimator'), root);
    root.querySelector('#bias + p').remove();
    expect(locate(root, anchor)).toBeNull();
    root.innerHTML = '<p>same phrase same phrase</p>';
    expect(locate(root, { quote: 'phrase' })).toBeNull();
  });

  it('does not insert HTML marks between rows or inside SVG', () => {
    mount('<div class="post-content"><table><tbody><tr><td>First</td></tr>\n<tr><td>Last</td></tr>\n</tbody></table><svg><text>Chart</text></svg></div>');
    const root = document.querySelector('.post-content');
    const range = document.createRange();
    range.selectNodeContents(root);
    wrapRange(range, 'all');
    expect(root.querySelector('tbody > mark, svg mark')).toBeNull();
    expect(root.querySelectorAll('td mark')).toHaveLength(2);
  });

  it('uses physical shortcut keys on macOS and respects composition and handled events', () => {
    mount(CONTENT + PANEL);
    const store = createStore(fakeStorage());
    initArticle(document.querySelector('[data-reading-state]'), store);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(rangeOver(document.querySelector('.post-content'), 'lazy dog'));
    const settings = { key: 'Ó', code: 'KeyH', altKey: true, shiftKey: true, cancelable: true };
    document.dispatchEvent(new KeyboardEvent('keydown', { ...settings, isComposing: true }));
    const handled = new KeyboardEvent('keydown', settings);
    handled.preventDefault();
    document.dispatchEvent(handled);
    expect(store.read(ARTICLE)).toBeNull();
    document.dispatchEvent(new KeyboardEvent('keydown', settings));
    expect(store.read(ARTICLE).annotations[0].quote).toBe('lazy dog');
    document.querySelector('[data-reading-erase-article]').click();
  });
});
