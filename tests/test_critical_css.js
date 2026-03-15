import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';
import assert from 'assert';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const includesDir = path.resolve(rootDir, '_includes', 'critical-css');
const headPath = path.resolve(rootDir, '_includes', 'head.html');

const requiredFiles = ['home.html', 'default.html', 'post.html'];
const MAX_INLINE_SIZE = 14 * 1024; // 14KB

function ensureCriticalFilesExist() {
  requiredFiles.forEach((file) => {
    const filePath = path.resolve(includesDir, file);
    assert.ok(fs.existsSync(filePath), `Missing critical CSS file: ${file}`);
    const stats = fs.statSync(filePath);
    assert.ok(stats.size < MAX_INLINE_SIZE, `${file} exceeds 14KB inline size budget`);
  });
}

function ensureAsyncStylesheetLoad(headSource) {
  assert.ok(
    headSource.includes("rel=\"preload\" href=\"{{ main_stylesheet }}\" as=\"style\""),
    'Main stylesheet preload link is missing or misconfigured.'
  );
  assert.ok(
    headSource.includes("media=\"print\" onload=\"this.media='all'\""),
    'Main stylesheet is not loaded asynchronously using media swap.'
  );
  assert.ok(
    headSource.includes('<noscript>') && headSource.includes('{{ main_stylesheet }}" />'),
    'Missing <noscript> fallback for main stylesheet.'
  );
}

function ensureCriticalInline(headSource) {
  assert.ok(
    headSource.includes('data-critical-css'),
    'Critical CSS inline block is not present in head include.'
  );
}

(function run() {
  ensureCriticalFilesExist();
  const headSource = fs.readFileSync(headPath, 'utf8');
  ensureAsyncStylesheetLoad(headSource);
  ensureCriticalInline(headSource);
  console.log('Critical CSS configuration tests passed.');
})();
