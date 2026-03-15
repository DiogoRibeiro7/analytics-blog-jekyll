#!/usr/bin/env node

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');
const SITE_DIR = path.join(ROOT, '_site');

const HTML_EXTENSIONS = new Set(['.html']);

async function walk(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.isDirectory()) {
      const nested = await walk(path.join(directory, entry.name));
      files.push(...nested);
    } else if (HTML_EXTENSIONS.has(path.extname(entry.name))) {
      files.push(path.join(directory, entry.name));
    }
  }

  return files;
}

function extractExternalAssets(content) {
  const results = [];
  const scriptRegex = /<script\b[^>]*src=["'](https?:\/\/[^"']+)["'][^>]*>/gi;
  const linkRegex = /<link\b[^>]*rel=["'][^"']*(?:stylesheet|preload)[^"']*["'][^>]*href=["'](https?:\/\/[^"']+)["'][^>]*>/gi;

  let match;

  while ((match = scriptRegex.exec(content)) !== null) {
    results.push({ tag: match[0], url: match[1], type: 'script' });
  }

  while ((match = linkRegex.exec(content)) !== null) {
    results.push({ tag: match[0], url: match[1], type: 'style' });
  }

  return results;
}

function validateIntegrity(records, filePath) {
  const problems = [];

  for (const record of records) {
    if (!record.tag.includes('integrity=')) {
      problems.push(`${record.type.toUpperCase()} missing integrity for ${record.url}`);
      continue;
    }

    if (!/integrity=["']sha384-[A-Za-z0-9+/=]+["']/.test(record.tag)) {
      problems.push(`${record.type.toUpperCase()} has invalid integrity format for ${record.url}`);
    }

    if (!/crossorigin=["'][^"']+["']/.test(record.tag)) {
      problems.push(`${record.type.toUpperCase()} missing crossorigin attribute for ${record.url}`);
    }
  }

  if (problems.length > 0) {
    return { filePath, problems };
  }

  return null;
}

async function main() {
  try {
    await fs.access(SITE_DIR);
  } catch {
    throw new Error('The _site directory was not found. Run the Jekyll build before validating SRI.');
  }

  const htmlFiles = await walk(SITE_DIR);
  const failures = [];

  for (const filePath of htmlFiles) {
    const content = await fs.readFile(filePath, 'utf8');
    const assets = extractExternalAssets(content);
    if (assets.length === 0) {
      continue;
    }
    const result = validateIntegrity(assets, path.relative(ROOT, filePath));
    if (result) {
      failures.push(result);
    }
  }

  if (failures.length > 0) {
    console.error('SRI validation failed:');
    for (const failure of failures) {
      console.error(`- ${failure.filePath}`);
      failure.problems.forEach((problem) => {
        console.error(`  • ${problem}`);
      });
    }
    process.exitCode = 1;
    return;
  }

  console.log('All external assets include valid SRI metadata.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
