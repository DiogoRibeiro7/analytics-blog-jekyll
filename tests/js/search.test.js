import { describe, expect, it, vi } from 'vitest';
import { createSearchEngine, buildSuggestionPool } from '../../assets/js/search/engine.js';
import { debounce, updateLiveRegion, setupSearchEnhancements } from '../../assets/js/search.js';

const advanceTimers = async (ms = 0) => {
  vi.advanceTimersByTime(ms);
  await Promise.resolve();
};

describe('search utilities', () => {
  it('debounce delays invocation and exposes cancel method', async () => {
    const spy = vi.fn();
    const debounced = debounce(spy, 100);

    debounced('first');
    debounced('second');
    expect(spy).not.toHaveBeenCalled();

    await advanceTimers(99);
    expect(spy).not.toHaveBeenCalled();

    await advanceTimers(2);
    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy).toHaveBeenCalledWith('second');

    debounced('third');
    debounced.cancel();
    await advanceTimers(200);
    expect(spy).toHaveBeenCalledTimes(1);
  });

  it('updates aria-live regions while preserving toggle visibility', () => {
    const region = document.createElement('div');
    region.setAttribute('hidden', '');

    updateLiveRegion(region, '3 results found');
    expect(region.textContent).toBe('3 results found');
    expect(region.hasAttribute('hidden')).toBe(false);

    updateLiveRegion(region, '3 results found');
    expect(region.textContent.endsWith('\u00A0')).toBe(true);

    updateLiveRegion(region, '');
    expect(region.getAttribute('hidden')).toBe('');
  });

  it('searches documents with filters and builds suggestions', () => {
    const engine = createSearchEngine([
      {
        title: 'Understanding Python Integrals',
        summary: 'Integral calculus primer',
        content: 'Integrals and code',
        type: 'post',
        languages: ['python'],
        difficulty: 'intermediate',
        tags: ['math', 'python'],
        math: ['\\int_0^1 x^2 \\, dx'],
        code: [{ language: 'python', code: 'def integrate(): pass' }]
      },
      {
        title: 'Beginner Guide to Rust',
        summary: 'Ownership basics',
        content: 'Rust patterns',
        type: 'post',
        languages: ['rust'],
        difficulty: 'beginner',
        tags: ['rust']
      }
    ]);

    const results = engine.search('integral python', {
      type: 'post',
      language: 'python',
      difficulty: 'intermediate',
      tags: new Set(['math'])
    });

    expect(results).toHaveLength(1);
    expect(results[0].score).toBeGreaterThan(0);
    expect(results[0].codeSnippet.language).toBe('python');

    const pool = buildSuggestionPool(engine.getDocuments(), 5);
    expect(pool).toContain('Understanding Python Integrals');
    expect(pool).toContain('#math');
  });

  it('wires up enhanced interactions for the search UI', async () => {
    document.body.innerHTML = `
      <div data-search-app>
        <form data-search-form></form>
        <input data-search-input />
        <div data-search-filters></div>
        <div data-filter-tags></div>
        <div data-search-region aria-busy="false"></div>
        <div data-search-live="count"></div>
        <div data-search-live="selection"></div>
        <div data-search-live="status"></div>
        <div data-search-loading hidden></div>
        <div data-search-empty hidden></div>
        <ul data-search-results></ul>
      </div>
    `;

    const app = document.querySelector('[data-search-app]');
    const form = app.querySelector('[data-search-form]');
    const input = app.querySelector('[data-search-input]');
    const results = app.querySelector('[data-search-results]');
    const filtersContainer = app.querySelector('[data-search-filters]');
    const tagsContainer = app.querySelector('[data-filter-tags]');
    const liveSelection = app.querySelector('[data-search-live="selection"]');
    const liveStatus = app.querySelector('[data-search-live="status"]');
    const liveCount = app.querySelector('[data-search-live="count"]');
    const empty = app.querySelector('[data-search-empty]');

    let ignoreSubmit = false;

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (ignoreSubmit) {
        ignoreSubmit = false;
        return;
      }
      empty.hidden = true;
      results.innerHTML = `
        <li class="search-result">
          <a data-result-link href="http://localhost/posts/python">Python Search Result</a>
        </li>
      `;
      globalThis.MockMutationObservers.forEach((observer) => observer.trigger());
    });

    const locationStub = {
      href: 'http://localhost/search/',
      assign: vi.fn(function assign(url) {
        this.href = url;
      }),
      toString() {
        return this.href;
      }
    };
    vi.stubGlobal('location', locationStub);
    try {
      window.location.assign = locationStub.assign;
    } catch (error) {
      // ignore if location.assign is read-only
    }

    setupSearchEnhancements();

    const filterSelect = document.createElement('select');
    filtersContainer.appendChild(filterSelect);

    const tagButton = document.createElement('button');
    tagButton.dataset.filterTag = 'python';
    tagButton.type = 'button';
    tagsContainer.appendChild(tagButton);

    globalThis.MockMutationObservers.forEach((observer) => observer.trigger());

    input.value = 'python';
    input.dispatchEvent(new Event('input', { bubbles: true }));

    await advanceTimers(400);

    expect(results.querySelector('.search-result')).not.toBeNull();
    expect(liveStatus.textContent.trim().toLowerCase()).toContain('results updated');
    expect(liveCount.textContent).toContain('1 result');

    // Tab is left to the browser; the search used to trap focus among the filters.
    const tabFromInput = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
    input.dispatchEvent(tabFromInput);
    expect(tabFromInput.defaultPrevented).toBe(false);

    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    expect(results.querySelector('.search-result').classList.contains('is-active')).toBe(true);
    expect(liveSelection.textContent).toContain('Result 1 of 1');

    const tabFromFilter = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
    filterSelect.dispatchEvent(tabFromFilter);
    expect(tabFromFilter.defaultPrevented).toBe(false);

    ignoreSubmit = true;
    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    expect(input.value).toBe('');
    expect(liveStatus.textContent).toContain('Search cleared');

    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  });
});
