import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';
import assert from 'assert';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const searchHtmlPath = path.resolve(rootDir, 'search', 'index.html');
const searchJsPath = path.resolve(rootDir, 'assets', 'js', 'search.js');
const searchScssPath = path.resolve(rootDir, '_sass', '_search.scss');

const searchHtml = fs.readFileSync(searchHtmlPath, 'utf8');
const searchJs = fs.readFileSync(searchJsPath, 'utf8');
const searchScss = fs.readFileSync(searchScssPath, 'utf8');

function contains(source, needle, message) {
  assert.ok(source.includes(needle), message);
}

function ensureKeyboardAccessibleMarkup() {
  contains(searchHtml, 'data-search-input', 'Search input missing keyboard data attribute.');
  contains(searchHtml, 'role="listbox"', 'Results list must expose listbox role.');
  contains(searchHtml, 'role="option"', 'Result options must expose ARIA role.');
  contains(searchHtml, 'data-search-loading', 'Loading spinner container missing.');
  contains(searchScss, '.search-filter__tag:focus-visible', 'Filter focus-visible styles missing.');
  contains(searchScss, 'is-active .search-result__card', 'Active result highlight styles missing.');
}

function ensureAriaAttributesPresent() {
  contains(searchHtml, 'aria-activedescendant', 'Search input must expose aria-activedescendant.');
  contains(searchHtml, 'data-search-live="count"', 'Missing ARIA live region for result counts.');
  contains(searchHtml, 'data-search-live="selection"', 'Missing ARIA live region for selection.');
  contains(searchHtml, 'data-search-live="status"', 'Missing ARIA live region for status.');
  contains(searchHtml, 'data-search-region', 'Results region must expose aria-busy target.');
}

function ensureKeyboardHandlersImplemented() {
  contains(searchJs, 'ArrowDown', 'Down arrow handler missing.');
  contains(searchJs, 'ArrowUp', 'Up arrow handler missing.');
  contains(searchJs, 'event.key === "Tab"', 'Tab key handling missing.');
  contains(searchJs, '"Escape"', 'Escape key handling missing.');
  contains(searchJs, 'window.location.assign', 'Enter key navigation missing.');
  contains(searchJs, 'aria-activedescendant', 'Result focus management missing.');
}

function ensureVisualFeedback() {
  contains(searchHtml, 'search-app__spinner', 'Spinner markup missing.');
  contains(searchScss, 'search-spinner', 'Spinner animation missing.');
  contains(searchHtml, 'search-app__no-results-illustration', 'No results illustration missing.');
}

function ensureDebounceLogic() {
  contains(searchJs, 'function debounce', 'Debounce utility missing.');
  contains(searchJs, 'debounced.cancel', 'Debounce cancel missing for Escape handling.');
  contains(searchJs, 'DEBOUNCE_DELAY = 300', 'Debounce delay must be 300ms.');
}

(function run() {
  ensureKeyboardAccessibleMarkup();
  ensureAriaAttributesPresent();
  ensureKeyboardHandlersImplemented();
  ensureVisualFeedback();
  ensureDebounceLogic();
  console.log('Search accessibility enhancements verified.');
})();
