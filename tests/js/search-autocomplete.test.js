import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createAutocomplete } from '../../assets/js/search/autocomplete.js';

describe('createAutocomplete', () => {
  let panel;
  let onSelectMock;

  beforeEach(() => {
    document.body.innerHTML = '';
    panel = document.createElement('div');
    panel.dataset.searchAutocomplete = '';
    panel.hidden = true;
    document.body.appendChild(panel);
    onSelectMock = vi.fn();
  });

  it('returns stub when panel is null', () => {
    const autocomplete = createAutocomplete({ panel: null, limit: 8, onSelect: onSelectMock });

    expect(autocomplete).toBeDefined();
    expect(autocomplete.setSuggestions).toBeDefined();
    expect(autocomplete.update).toBeDefined();
    expect(autocomplete.close).toBeDefined();
    expect(autocomplete.handleNavigation).toBeDefined();

    // Should not throw when called
    autocomplete.setSuggestions(['test']);
    autocomplete.update('query');
    autocomplete.close();
    autocomplete.handleNavigation({}, null);
  });

  it('sets suggestions from array', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python', 'ruby']);

    autocomplete.update('java');

    expect(panel.hidden).toBe(false);
    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(1);
    expect(options[0].dataset.value).toBe('javascript');
  });

  it('filters suggestions based on query', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'java', 'python', 'ruby']);

    autocomplete.update('java');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(2);
    expect(options[0].dataset.value).toBe('javascript');
    expect(options[1].dataset.value).toBe('java');
  });

  it('respects limit parameter', () => {
    const autocomplete = createAutocomplete({ panel, limit: 2, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'java', 'jython', 'jruby']);

    autocomplete.update('j');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(2);
  });

  it('clears panel when query is empty', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python']);

    autocomplete.update('java');
    expect(panel.hidden).toBe(false);

    autocomplete.update('');
    expect(panel.hidden).toBe(true);
    expect(panel.innerHTML).toBe('');
  });

  it('clears panel when no matches found', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python']);

    autocomplete.update('ruby');

    expect(panel.hidden).toBe(true);
    expect(panel.innerHTML).toBe('');
  });

  it('handles ArrowDown navigation', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    autocomplete.setSuggestions(['javascript', 'java', 'python']);
    autocomplete.update('java');

    const event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });

    autocomplete.handleNavigation(event, input);

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options[0].getAttribute('aria-selected')).toBe('true');
    expect(options[0].classList.contains('is-active')).toBe(true);
  });

  it('handles ArrowUp navigation', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    autocomplete.setSuggestions(['javascript', 'java', 'python']);
    autocomplete.update('java');

    // Press ArrowDown twice
    let event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });
    autocomplete.handleNavigation(event, input);
    autocomplete.handleNavigation(event, input);

    // Press ArrowUp once
    event = new KeyboardEvent('keydown', { key: 'ArrowUp' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });
    autocomplete.handleNavigation(event, input);

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options[0].getAttribute('aria-selected')).toBe('true');
  });

  it('wraps around when navigating with ArrowDown', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    autocomplete.setSuggestions(['javascript', 'java']);
    autocomplete.update('java');

    const event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });

    // Navigate to second item
    autocomplete.handleNavigation(event, input);
    autocomplete.handleNavigation(event, input);

    // Should wrap to first item
    autocomplete.handleNavigation(event, input);

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options[0].getAttribute('aria-selected')).toBe('true');
  });

  it('selects option with Enter key', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    input.value = '';
    autocomplete.setSuggestions(['javascript', 'java']);
    autocomplete.update('java');

    // Navigate to first option
    let event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });
    autocomplete.handleNavigation(event, input);

    // Press Enter
    event = new KeyboardEvent('keydown', { key: 'Enter' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });
    autocomplete.handleNavigation(event, input);

    expect(input.value).toBe('javascript');
    expect(onSelectMock).toHaveBeenCalledWith('javascript');
    expect(panel.hidden).toBe(true);
  });

  it('does not handle navigation when panel is hidden', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    panel.hidden = true;

    const event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });

    autocomplete.handleNavigation(event, input);

    expect(event.preventDefault).not.toHaveBeenCalled();
  });

  it('handles click on autocomplete option', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python']);
    autocomplete.update('java');

    const option = panel.querySelector('[data-autocomplete-option]');
    option.click();

    expect(onSelectMock).toHaveBeenCalledWith('javascript');
    expect(panel.hidden).toBe(true);
  });

  it('ignores click outside autocomplete options', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript']);
    autocomplete.update('java');

    panel.click();

    expect(onSelectMock).not.toHaveBeenCalled();
    expect(panel.hidden).toBe(false);
  });

  it('closes autocomplete panel', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python']);
    autocomplete.update('java');

    expect(panel.hidden).toBe(false);

    autocomplete.close();

    expect(panel.hidden).toBe(true);
    expect(panel.innerHTML).toBe('');
  });

  it('handles empty suggestions array', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions([]);

    autocomplete.update('test');

    expect(panel.hidden).toBe(true);
  });

  it('filters out null/undefined suggestions', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', null, 'python', undefined, 'ruby']);

    autocomplete.update('a');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(1); // Only javascript matches 'a'
    expect(options[0].dataset.value).toBe('javascript');
  });

  it('performs case-insensitive matching', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['JavaScript', 'Python', 'Ruby']);

    autocomplete.update('JAVA');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(1);
    expect(options[0].dataset.value).toBe('JavaScript');
  });

  it('trims whitespace from query', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    autocomplete.setSuggestions(['javascript', 'python']);

    autocomplete.update('  java  ');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(1);
    expect(options[0].dataset.value).toBe('javascript');
  });

  it('resets suggestion index on update', () => {
    const autocomplete = createAutocomplete({ panel, limit: 8, onSelect: onSelectMock });
    const input = document.createElement('input');
    autocomplete.setSuggestions(['javascript', 'java', 'python']);

    autocomplete.update('java');

    // Navigate to second item
    let event = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    Object.defineProperty(event, 'preventDefault', { value: vi.fn() });
    autocomplete.handleNavigation(event, input);

    // Update with new query - should reset index
    autocomplete.update('py');

    const options = panel.querySelectorAll('[data-autocomplete-option]');
    expect(options.length).toBe(1);
    expect(options[0].getAttribute('aria-selected')).toBe('false');
  });
});
