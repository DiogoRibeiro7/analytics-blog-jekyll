import { strict as assert } from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import YAML from 'yaml';

const ROOT = path.resolve(process.cwd());
const DATA_FILE = path.join(ROOT, '_data', 'cdn-integrity.yml');

assert.ok(fs.existsSync(DATA_FILE), 'cdn-integrity data file is missing');

const rawYaml = fs.readFileSync(DATA_FILE, 'utf8');
const data = YAML.parse(rawYaml);

assert.ok(data && typeof data === 'object', 'cdn-integrity.yml did not parse into an object');
const entries = Object.entries(data);
assert.ok(entries.length > 0, 'cdn-integrity.yml does not contain any CDN entries');

for (const [url, attributes] of entries) {
  assert.ok(url.startsWith('https://'), `SRI entry key must be an https URL: ${url}`);
  assert.ok(attributes.integrity, `Missing integrity value for ${url}`);
  assert.match(attributes.integrity, /^sha384-[A-Za-z0-9+/=]+$/, `Integrity for ${url} is not a valid SHA-384 hash`);
  assert.equal(attributes.crossorigin, 'anonymous', `crossorigin should be "anonymous" for ${url}`);
}

console.log('SRI data file validated successfully.');
