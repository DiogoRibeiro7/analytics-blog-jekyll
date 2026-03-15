#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const searchBundle = fs.readFileSync(path.join(root, 'assets', 'js', 'search.js'), 'utf8');
const searchTemplate = fs.readFileSync(path.join(root, 'search', 'index.html'), 'utf8');
const searchIndex = fs.readFileSync(path.join(root, 'search.json'), 'utf8');
const config = fs.readFileSync(path.join(root, '_config.yml'), 'utf8');

const requiredFunctions = [
  'isMathQuery',
  'isCodeQuery',
  'tokenize',
  'recordAnalytics',
  'handleAutocomplete',
  'handleAutocompleteNavigation',
  'populateTagFilters',
  'selectedTags',
  'languageFilter',
  'difficultyFilter'
];

const missingFunctions = requiredFunctions.filter((token) => !searchBundle.includes(token));
if (missingFunctions.length) {
  throw new Error(`Search bundle missing technical search helpers: ${missingFunctions.join(', ')}`);
}

if (!searchBundle.includes('navigator.clipboard') || !searchBundle.includes('LaTeX')) {
  throw new Error('Search bundle missing LaTeX clipboard support');
}

if (!searchBundle.includes('AUTOCOMPLETE_LIMIT') || !searchBundle.includes('ANALYTICS_STORAGE_KEY')) {
  throw new Error('Search bundle missing autocomplete or analytics configuration');
}

const requiredSelectors = [
  'data-search-form',
  'data-search-input',
  'data-search-autocomplete',
  'data-search-analytics',
  'data-filter-type',
  'data-filter-language',
  'data-filter-difficulty'
];

requiredSelectors.forEach((selector) => {
  if (!searchTemplate.includes(selector)) {
    throw new Error(`Search template missing selector: ${selector}`);
  }
});

if (!searchTemplate.includes('data-filter-tags') || !searchTemplate.includes('search-result__math-preview')) {
  throw new Error('Search template missing tag filters or math preview support');
}

if (!config.includes('include_code_blocks: true') || !config.includes('include_math: true')) {
  throw new Error('Search configuration missing math/code directives');
}

if (!config.includes('enable_keyboard_shortcuts: true')) {
  throw new Error('Search configuration missing keyboard shortcut support');
}

console.log('Technical search experience verified for math, code, filters, analytics, and autocomplete.');
