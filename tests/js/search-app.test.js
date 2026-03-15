import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initializeSearchApp } from '../../assets/js/search/app.js';

describe('initializeSearchApp', () => {
  let mockApp;
  let fetchMock;
  let originalFetch;
  let originalHistory;

  beforeEach(() => {
    // Clear document
    document.body.innerHTML = '';

    // Mock window.location
    delete window.location;
    window.location = {
      href: 'http://localhost/search',
      pathname: '/search',
      search: ''
    };

    // Mock window.history
    originalHistory = window.history;
    window.history = {
      replaceState: vi.fn()
    };

    // Mock fetch
    originalFetch = global.fetch;
    fetchMock = vi.fn();
    global.fetch = fetchMock;

    // Create minimal DOM structure
    mockApp = document.createElement('div');
    mockApp.setAttribute('data-search-app', '');
    mockApp.setAttribute('data-search-index', '/test-search.json');

    const mockForm = document.createElement('form');
    mockForm.setAttribute('data-search-form', '');

    const mockInput = document.createElement('input');
    mockInput.setAttribute('data-search-input', '');

    const mockResultsList = document.createElement('div');
    mockResultsList.setAttribute('data-search-results', '');

    const mockResultsMeta = document.createElement('div');
    mockResultsMeta.setAttribute('data-search-meta', '');

    const mockEmptyState = document.createElement('div');
    mockEmptyState.setAttribute('data-search-empty', '');

    const mockAutocompletePanel = document.createElement('div');
    mockAutocompletePanel.setAttribute('data-search-autocomplete', '');
    mockAutocompletePanel.hidden = true;

    const mockAnalyticsPanel = document.createElement('div');
    mockAnalyticsPanel.setAttribute('data-search-analytics', '');
    mockAnalyticsPanel.innerHTML = '<ul class="search-app__analytics-list"></ul><div class="search-app__analytics-empty"></div>';

    const mockTemplate = document.createElement('template');
    mockTemplate.id = 'search-result-template';
    mockTemplate.innerHTML = '<div><a data-result-link></a><div data-result-summary></div></div>';

    const mockFilterType = document.createElement('select');
    mockFilterType.setAttribute('data-filter-type', '');

    const mockFilterLanguage = document.createElement('select');
    mockFilterLanguage.setAttribute('data-filter-language', '');

    const mockFilterDifficulty = document.createElement('select');
    mockFilterDifficulty.setAttribute('data-filter-difficulty', '');

    const mockFilterTagsContainer = document.createElement('div');
    mockFilterTagsContainer.setAttribute('data-filter-tags', '');

    mockApp.appendChild(mockForm);
    mockApp.appendChild(mockInput);
    mockApp.appendChild(mockResultsList);
    mockApp.appendChild(mockResultsMeta);
    mockApp.appendChild(mockEmptyState);
    mockApp.appendChild(mockAutocompletePanel);
    mockApp.appendChild(mockAnalyticsPanel);
    mockApp.appendChild(mockFilterType);
    mockApp.appendChild(mockFilterLanguage);
    mockApp.appendChild(mockFilterDifficulty);
    mockApp.appendChild(mockFilterTagsContainer);

    document.body.appendChild(mockApp);
    document.body.appendChild(mockTemplate);

    // Mock successful fetch by default
    fetchMock.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({
        documents: [
          { id: '1', title: 'Test 1', content: 'JavaScript tutorial', type: 'post', tags: ['js'] },
          { id: '2', title: 'Test 2', content: 'Python guide', type: 'tutorial', tags: ['python'] }
        ]
      })
    });
  });

  afterEach(() => {
    global.fetch = originalFetch;
    window.history = originalHistory;
  });

  it('returns early when app element is not found', () => {
    document.body.innerHTML = '';

    expect(() => initializeSearchApp()).not.toThrow();
  });

  it('calls fetch for search index on initialization', () => {
    initializeSearchApp();

    // Fetch should be called (will be async but we just verify the call happened)
    expect(fetchMock).toHaveBeenCalledWith('/test-search.json', { credentials: 'same-origin' });
  });

  it('uses default search index URL when attribute not specified', () => {
    mockApp.removeAttribute('data-search-index');

    initializeSearchApp();

    expect(fetchMock).toHaveBeenCalledWith('/search.json', { credentials: 'same-origin' });
  });

  it('sets up form submit handler', () => {
    initializeSearchApp();

    const form = mockApp.querySelector('[data-search-form]');
    const submitEvent = new Event('submit', { bubbles: true, cancelable: true });
    const preventDefaultSpy = vi.spyOn(submitEvent, 'preventDefault');

    form.dispatchEvent(submitEvent);

    expect(preventDefaultSpy).toHaveBeenCalled();
  });

  it('sets up input event handler for autocomplete', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    input.value = 'test';

    expect(() => {
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }).not.toThrow();
  });

  it('sets up filter change handlers', () => {
    initializeSearchApp();

    const filterType = mockApp.querySelector('[data-filter-type]');
    filterType.value = 'tutorial';

    expect(() => {
      filterType.dispatchEvent(new Event('change', { bubbles: true }));
    }).not.toThrow();
  });

  it('handles tag filter clicks', () => {
    initializeSearchApp();

    const tagButton = document.createElement('button');
    tagButton.setAttribute('data-filter-tag', 'javascript');
    tagButton.setAttribute('aria-pressed', 'false');
    mockApp.appendChild(tagButton);

    tagButton.click();
    expect(tagButton.getAttribute('aria-pressed')).toBe('true');

    tagButton.click();
    expect(tagButton.getAttribute('aria-pressed')).toBe('false');
  });

  it('handles "/" keyboard shortcut to focus input', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    const focusSpy = vi.spyOn(input, 'focus');
    const selectSpy = vi.spyOn(input, 'select');

    const keyEvent = new KeyboardEvent('keydown', { key: '/', bubbles: true, cancelable: true });
    const preventDefaultSpy = vi.spyOn(keyEvent, 'preventDefault');

    document.dispatchEvent(keyEvent);

    expect(preventDefaultSpy).toHaveBeenCalled();
    expect(focusSpy).toHaveBeenCalled();
    expect(selectSpy).toHaveBeenCalled();
  });

  it('handles "Ctrl+K" keyboard shortcut', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    const focusSpy = vi.spyOn(input, 'focus');

    const keyEvent = new KeyboardEvent('keydown', {
      key: 'k',
      ctrlKey: true,
      bubbles: true,
      cancelable: true
    });
    const preventDefaultSpy = vi.spyOn(keyEvent, 'preventDefault');

    document.dispatchEvent(keyEvent);

    expect(preventDefaultSpy).toHaveBeenCalled();
    expect(focusSpy).toHaveBeenCalled();
  });

  it('handles "Cmd+K" keyboard shortcut on Mac', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    const focusSpy = vi.spyOn(input, 'focus');

    const keyEvent = new KeyboardEvent('keydown', {
      key: 'K',
      metaKey: true,
      bubbles: true,
      cancelable: true
    });

    document.dispatchEvent(keyEvent);

    expect(focusSpy).toHaveBeenCalled();
  });

  it('ignores "/" shortcut when input is focused', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    input.focus();

    const keyEvent = new KeyboardEvent('keydown', {
      key: '/',
      bubbles: true,
      cancelable: true
    });
    const preventDefaultSpy = vi.spyOn(keyEvent, 'preventDefault');

    document.dispatchEvent(keyEvent);

    expect(preventDefaultSpy).not.toHaveBeenCalled();
  });

  it('ignores "/" shortcut when textarea is focused', () => {
    const textarea = document.createElement('textarea');
    document.body.appendChild(textarea);
    textarea.focus();

    initializeSearchApp();

    const keyEvent = new KeyboardEvent('keydown', {
      key: '/',
      bubbles: true,
      cancelable: true
    });
    const preventDefaultSpy = vi.spyOn(keyEvent, 'preventDefault');

    document.dispatchEvent(keyEvent);

    expect(preventDefaultSpy).not.toHaveBeenCalled();
  });

  it('closes autocomplete when clicking outside', () => {
    initializeSearchApp();

    const autocompletePanel = mockApp.querySelector('[data-search-autocomplete]');
    autocompletePanel.hidden = false;

    const outsideElement = document.createElement('div');
    document.body.appendChild(outsideElement);

    outsideElement.click();

    expect(autocompletePanel.hidden).toBe(true);
  });

  it('shows loading message when search executed before index ready', () => {
    fetchMock.mockImplementation(() => new Promise(() => {})); // Never resolves

    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    const form = mockApp.querySelector('[data-search-form]');
    const resultsMeta = mockApp.querySelector('[data-search-meta]');

    input.value = 'test';
    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

    expect(resultsMeta.textContent).toBe('Loading technical index…');
  });

  it('handles Escape key to clear input and execute search callback', () => {
    initializeSearchApp();

    const input = mockApp.querySelector('[data-search-input]');
    input.value = 'test query';

    const escapeEvent = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
    input.dispatchEvent(escapeEvent);

    expect(input.value).toBe('');
  });
});
