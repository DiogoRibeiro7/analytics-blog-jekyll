import fs from 'node:fs';
import path from 'node:path';
import YAML from 'yaml';
import { describe, expect, it } from 'vitest';

// Every CDN asset the theme loads is pinned by _data/cdn-integrity.yml. This
// check used to live in tests/test_sri.js, a script no test command ran.
describe('_data/cdn-integrity.yml', () => {
  const data = YAML.parse(fs.readFileSync(path.resolve('_data', 'cdn-integrity.yml'), 'utf8')) || {};
  const entries = Object.entries(data);

  it('lists CDN entries', () => {
    expect(entries.length).toBeGreaterThan(0);
  });

  it.each(entries)('%s has an https URL, a SHA-384 hash and anonymous CORS', (url, attributes) => {
    expect(url.startsWith('https://')).toBe(true);
    expect(attributes.integrity).toMatch(/^sha384-[A-Za-z0-9+/=]+$/);
    expect(attributes.crossorigin).toBe('anonymous');
  });
});
