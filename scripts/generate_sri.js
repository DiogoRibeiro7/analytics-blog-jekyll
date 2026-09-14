#!/usr/bin/env node

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import { execFile } from 'child_process';
import { promisify } from 'util';
import YAML from 'yaml';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');
const DATA_FILE = path.join(ROOT, '_data', 'cdn-integrity.yml');
const execFileAsync = promisify(execFile);

const IGNORED_DIRECTORIES = new Set([
  '.git',
  'node_modules',
  '_site',
  '.jekyll-cache',
  '.sass-cache',
  'tmp',
  'coverage',
  'test-results',
  'playwright-report'
]);

// Google Fonts tailors the CSS it serves to the requesting browser, so a hash
// computed here never matches what the browser receives and integrity checks
// would block the stylesheet. Leave those resources without SRI.
const SRI_EXEMPT_HOSTS = ['https://fonts.googleapis.com', 'https://www.googletagmanager.com'];
const HTML_EXTENSIONS = new Set(['.html', '.liquid']);

const KNOWN_CDN_HINTS = [
  'https://cdn.jsdelivr.net',
  'https://cdnjs.cloudflare.com',
  'https://fonts.googleapis.com',
  'https://fonts.gstatic.com',
  'https://www.googletagmanager.com',
  'https://cdn.plot.ly',
  'https://charts.mongodb.com'
];

function isHtmlLike(filePath) {
  return HTML_EXTENSIONS.has(path.extname(filePath));
}

async function walk(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.name.startsWith('.')) {
      // still inspect hidden files that are html-like, but avoid hidden directories
      if (entry.isDirectory()) {
        continue;
      }
    }

    if (entry.isDirectory()) {
      if (IGNORED_DIRECTORIES.has(entry.name)) {
        continue;
      }
      const nested = await walk(path.join(directory, entry.name));
      files.push(...nested);
    } else if (isHtmlLike(entry.name)) {
      files.push(path.join(directory, entry.name));
    }
  }

  return files;
}

function shouldTrackResource(url) {
  if (!url.startsWith('https://')) {
    return false;
  }

  if (SRI_EXEMPT_HOSTS.some((host) => url.startsWith(host))) {
    return false;
  }

  if (url.includes('.js') || url.includes('.css')) {
    return true;
  }

  return KNOWN_CDN_HINTS.some((hint) => url.startsWith(hint));
}

function normalizeUrl(url) {
  return url.replace(/[),;]+$/, '');
}

function extractUrlsFromContent(content) {
  const urlRegex = /https:\/\/[\w\-./?=&%#:~+,;@]+/g;
  const matches = content.match(urlRegex) || [];
  return matches
    .map((candidate) => normalizeUrl(candidate))
    .filter((candidate) => shouldTrackResource(candidate));
}

async function fetchResource(url) {
  try {
    const { stdout } = await execFileAsync('curl', ['-fsSL', url], {
      encoding: 'buffer',
      maxBuffer: 10 * 1024 * 1024
    });
    return stdout;
  } catch (error) {
    const stderr = error.stderr ? error.stderr.toString().trim() : '';
    const suffix = stderr ? `: ${stderr}` : `: ${error.message}`;
    throw new Error(`Failed to fetch ${url}${suffix}`);
  }
}

function computeIntegrity(buffer) {
  const hash = crypto.createHash('sha384').update(buffer).digest('base64');
  return `sha384-${hash}`;
}

function isFetchableResource(url) {
  if (url.includes('fonts.googleapis.com/css')) {
    return true;
  }

  if (/\.(js|css)(\?|$)/.test(url)) {
    return true;
  }

  return false;
}

function shouldSkipFetch(url) {
  if (!isFetchableResource(url)) {
    return true;
  }

  if (url.startsWith('https://www.googletagmanager.com/gtag/js') && /=\s*$/.test(url)) {
    return true;
  }

  return false;
}

function augmentDerivedResources(urls) {
  const derived = new Set();

  for (const url of urls) {
    if (/cdn\.jsdelivr\.net\/npm\/katex@/i.test(url)) {
      const base = url.endsWith('/') ? url : `${url}/`;
      derived.add(`${base}katex.min.css`);
      derived.add(`${base}katex.min.js`);
      derived.add(`${base}contrib/auto-render.min.js`);
    }
  }

  derived.forEach((resource) => urls.add(resource));
}

async function main() {
  const htmlFiles = await walk(ROOT);
  const urls = new Set();

  for (const filePath of htmlFiles) {
    const content = await fs.readFile(filePath, 'utf8');
    const extracted = extractUrlsFromContent(content);
    extracted.forEach((url) => urls.add(url));
  }

  augmentDerivedResources(urls);

  if (urls.size === 0) {
    console.warn('No CDN resources detected in HTML files.');
  }

  const results = {};

  for (const url of urls) {
    if (shouldSkipFetch(url)) {
      continue;
    }

    try {
      const buffer = await fetchResource(url);
      results[url] = {
        integrity: computeIntegrity(buffer),
        crossorigin: 'anonymous'
      };
      console.log(`Generated SRI for ${url}`);
    } catch (error) {
      console.error(`Unable to generate SRI for ${url}: ${error.message}`);
    }
  }

  const sortedEntries = Object.keys(results)
    .sort()
    .reduce((acc, key) => {
      acc[key] = results[key];
      return acc;
    }, {});

  const yamlContent = YAML.stringify(sortedEntries, { sortMapEntries: true });
  await fs.writeFile(DATA_FILE, yamlContent, 'utf8');
  console.log(`Wrote integrity data to ${DATA_FILE}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
