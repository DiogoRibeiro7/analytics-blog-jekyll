#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const searchDir = path.join(root, 'assets', 'js', 'search');
const searchSources = [
  path.join(root, 'assets', 'js', 'search.js'),
  ...fs
    .readdirSync(searchDir)
    .filter((file) => file.endsWith('.js'))
    .map((file) => path.join(searchDir, file))
];
const searchBundle = searchSources.map((file) => fs.readFileSync(file, 'utf8')).join('\n');
const searchTemplate = fs.readFileSync(path.join(root, 'search', 'index.html'), 'utf8');

const requiredFunctions = [
  'isMathQuery',
  'isCodeQuery',
  'tokenize',
  'createAnalyticsManager',
  'createAutocomplete',
  'renderTagFilters',
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

console.log('Technical search experience verified for math, code, filters, analytics, and autocomplete.');
