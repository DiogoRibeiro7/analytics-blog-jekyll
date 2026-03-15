import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createAnalyticsManager } from '../../assets/js/search/analytics.js';

describe('createAnalyticsManager', () => {
  let panel;
  let list;
  let empty;
  let onSelectMock;

  beforeEach(() => {
    document.body.innerHTML = '';
    panel = document.createElement('div');
    list = document.createElement('ul');
    empty = document.createElement('div');
    empty.textContent = 'No recent searches';
    empty.hidden = true;

    panel.appendChild(list);
    panel.appendChild(empty);
    document.body.appendChild(panel);

    onSelectMock = vi.fn();

    // Clear localStorage before each test
    window.localStorage.clear();
  });

  it('returns stub when panel is null', () => {
    const manager = createAnalyticsManager({ panel: null, list, empty, onSelect: onSelectMock });

    expect(manager).toBeDefined();
    expect(manager.record).toBeDefined();
    expect(manager.render).toBeDefined();

    // Should not throw when called
    manager.record('test');
    manager.render();
  });

  it('returns stub when list is null', () => {
    const manager = createAnalyticsManager({ panel, list: null, empty, onSelect: onSelectMock });

    expect(manager.record).toBeDefined();
    manager.record('test');
  });

  it('returns stub when empty is null', () => {
    const manager = createAnalyticsManager({ panel, list, empty: null, onSelect: onSelectMock });

    expect(manager.record).toBeDefined();
    manager.record('test');
  });

  it('records a query and saves to localStorage', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');

    const stored = window.localStorage.getItem('datalog-search-analytics');
    expect(stored).toBeTruthy();

    const parsed = JSON.parse(stored);
    expect(parsed.javascript).toBe(1);
  });

  it('increments count for repeated queries', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.record('python');  // Different query to reset lastQuery
    manager.record('javascript');
    manager.record('ruby');
    manager.record('javascript');

    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.javascript).toBe(3);
  });

  it('does not record empty queries', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('');
    manager.record('   ');

    const stored = window.localStorage.getItem('datalog-search-analytics');
    expect(stored).toBeNull();
  });

  it('does not record duplicate consecutive queries', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.record('javascript');

    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.javascript).toBe(1);
  });

  it('records different queries separately', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.record('python');
    manager.record('ruby');

    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.javascript).toBe(1);
    expect(stored.python).toBe(1);
    expect(stored.ruby).toBe(1);
  });

  it('renders top 5 queries sorted by count', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    // Interleave queries to avoid consecutive duplicates
    manager.record('javascript');
    manager.record('python');
    manager.record('javascript');
    manager.record('ruby');
    manager.record('python');
    manager.record('java');
    manager.record('ruby');
    manager.record('go');
    manager.record('ruby');
    manager.record('go');
    manager.record('java');
    manager.record('go');
    manager.record('java');
    manager.record('go');
    manager.record('java');
    manager.record('go');
    manager.record('rust');
    manager.record('javascript');
    manager.record('rust');
    manager.record('javascript');
    manager.record('rust');
    manager.record('javascript');

    manager.render();

    const buttons = list.querySelectorAll('.search-analytics__query');
    expect(buttons.length).toBe(5);
    // Top queries should include those with highest counts
    expect(buttons[0].textContent).toMatch(/(javascript|go) \(5\)/);
    expect(buttons[1].textContent).toMatch(/(javascript|go) \(5\)|java \(4\)/);
  });

  it('shows empty state when no analytics', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.render();

    expect(empty.hidden).toBe(false);
    expect(list.innerHTML).toBe('');
  });

  it('hides empty state when analytics exist', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.render();

    expect(empty.hidden).toBe(true);
    expect(list.innerHTML).not.toBe('');
  });

  it('calls onSelect when query button is clicked', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.render();

    const button = list.querySelector('.search-analytics__query');
    button.click();

    expect(onSelectMock).toHaveBeenCalledWith('javascript');
  });

  it('loads analytics from localStorage on creation', () => {
    // Pre-populate localStorage
    window.localStorage.setItem('datalog-search-analytics', JSON.stringify({
      javascript: 5,
      python: 3
    }));

    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });
    manager.render();

    const buttons = list.querySelectorAll('.search-analytics__query');
    expect(buttons.length).toBe(2);
    expect(buttons[0].textContent).toContain('javascript');
    expect(buttons[0].textContent).toContain('(5)');
  });

  it('handles corrupted localStorage data', () => {
    window.localStorage.setItem('datalog-search-analytics', 'invalid json');

    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });
    manager.record('test');

    // Should not throw and should start fresh
    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.test).toBe(1);
  });

  it('handles localStorage with non-object data', () => {
    window.localStorage.setItem('datalog-search-analytics', JSON.stringify('string'));

    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });
    manager.record('test');

    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.test).toBe(1);
  });

  it('filters out single character queries from display', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('a');
    manager.record('javascript');
    manager.render();

    const buttons = list.querySelectorAll('.search-analytics__query');
    expect(buttons.length).toBe(1);
    expect(buttons[0].textContent).toContain('javascript');
  });

  it('handles localStorage save errors gracefully', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    // Mock localStorage to throw
    const originalSetItem = window.localStorage.setItem;
    window.localStorage.setItem = vi.fn(() => {
      throw new Error('Quota exceeded');
    });

    expect(() => manager.record('javascript')).not.toThrow();

    // Restore
    window.localStorage.setItem = originalSetItem;
  });

  it('handles localStorage load errors gracefully', () => {
    // Mock localStorage to throw on getItem
    const originalGetItem = window.localStorage.getItem;
    window.localStorage.getItem = vi.fn(() => {
      throw new Error('Access denied');
    });

    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    expect(manager).toBeDefined();
    expect(() => manager.record('test')).not.toThrow();

    // Restore
    window.localStorage.getItem = originalGetItem;
  });

  it('trims whitespace from queries before recording', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('  javascript  ');
    manager.record('javascript');

    const stored = JSON.parse(window.localStorage.getItem('datalog-search-analytics'));
    expect(stored.javascript).toBe(1);
  });

  it('renders automatically after recording', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    expect(list.innerHTML).toBe('');

    manager.record('javascript');

    const buttons = list.querySelectorAll('.search-analytics__query');
    expect(buttons.length).toBe(1);
  });

  it('creates proper button structure for each query', () => {
    const manager = createAnalyticsManager({ panel, list, empty, onSelect: onSelectMock });

    manager.record('javascript');
    manager.render();

    const listItem = list.querySelector('li');
    expect(listItem).toBeTruthy();

    const button = listItem.querySelector('button');
    expect(button.type).toBe('button');
    expect(button.className).toBe('search-analytics__query');
    expect(button.textContent).toBe('javascript (1)');
  });
});
