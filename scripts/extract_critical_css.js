import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs/promises';
import YAML from 'yaml';
// `critical` is pure ESM and exposes only named exports, so a default import
// resolves to undefined and the module fails to link.
import { generate } from 'critical';

import { spawnCompat } from './spawn_compat.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const includesDir = path.resolve(rootDir, '_includes', 'critical-css');
const configPath = path.resolve(rootDir, '_config.yml');

const DEFAULT_DIMENSIONS = [
  { width: 1920, height: 1080 },
  { width: 375, height: 667 }
];

const DEFAULT_PENTHOUSE_OPTIONS = {
  timeout: 30000
};

function isProduction() {
  const env = (process.env.JEKYLL_ENV || process.env.NODE_ENV || '').toLowerCase();
  return env === 'production';
}

async function readConfig() {
  try {
    const raw = await fs.readFile(configPath, 'utf8');
    return YAML.parse(raw) || {};
  } catch (error) {
    if (error.code === 'ENOENT') {
      return {};
    }
    throw error;
  }
}

function resolveCriticalSettings(config) {
  const settings = config.critical_css || {};
  const enabled = Boolean(settings.enabled);
  const dimensions = Array.isArray(settings.dimensions) && settings.dimensions.length > 0
    ? settings.dimensions.map((dimension) => ({
        width: Number(dimension.width) || DEFAULT_DIMENSIONS[0].width,
        height: Number(dimension.height) || DEFAULT_DIMENSIONS[0].height
      }))
    : DEFAULT_DIMENSIONS;
  const penthouseOptions = {
    ...DEFAULT_PENTHOUSE_OPTIONS,
    ...(settings.penthouse_options || {})
  };

  return { enabled, dimensions, penthouseOptions };
}

function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawnCompat(command, args, {
      stdio: 'inherit',
      env: process.env,
      cwd: rootDir,
      ...options
    });

    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
      }
    });
  });
}

async function buildSite(destination) {
  await runCommand('bundle', ['exec', 'jekyll', 'build', '--trace', '--destination', destination]);
}

async function locateSamplePost(buildDir) {
  // Posts do not live under /blog/. With `permalink: pretty` they render at
  // /YYYY/MM/DD/slug/, and blog/ only holds the listing plus its pagination, so
  // walking blog/ could only ever return a pagination page -- which is why the
  // post target used to extract the same CSS as the default one.
  // The body class carries the layout regardless of permalink style, so match
  // on that instead. Entries are sorted so the chosen post is stable run to run.
  const stack = [buildDir];

  while (stack.length > 0) {
    const current = stack.pop();
    const entries = await fs.readdir(current, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      const entryPath = path.resolve(current, entry.name);

      if (entry.isDirectory()) {
        stack.push(entryPath);
        continue;
      }

      if (entry.name !== 'index.html') {
        continue;
      }

      const html = await fs.readFile(entryPath, 'utf8');
      if (/<body[^>]*\blayout-post\b/.test(html)) {
        return path.relative(buildDir, entryPath).split(path.sep).join('/');
      }
    }
  }

  throw new Error('Unable to locate a generated post to extract critical CSS');
}

async function ensureIncludesDirectory() {
  await fs.mkdir(includesDir, { recursive: true });
}

async function writeCriticalFile(targetName, css) {
  const targetPath = path.resolve(includesDir, `${targetName}.html`);
  const trimmed = `${css.trim()}\n`;
  await fs.writeFile(targetPath, trimmed, 'utf8');
  console.log(`Wrote critical CSS → ${path.relative(rootDir, targetPath)}`);
}

async function extractCriticalForTarget({ baseDir, src, targetName, dimensions, penthouseOptions }) {
  console.log(`Generating critical CSS for ${targetName} from ${src}`);
  const { css } = await generate({
    base: baseDir,
    // Absolute src. critical resolves a root-anchored href like
    // /assets/css/main.css against the document's own directory, so a relative
    // src that sits in a subdirectory (blog/index.html, or any post) finds no
    // stylesheet and returns empty CSS without raising -- only the site root
    // happened to work, because there the document dir and base coincide.
    src: path.resolve(baseDir, src),
    inline: false,
    dimensions,
    // No `minify` key: critical removed it, and the option is redundant anyway
    // because generate() always runs the result through clean-css. Passing it
    // is rejected outright with `ConfigError: "minify" is not allowed`.
    extract: false,
    penthouse: penthouseOptions,
    rebase: false
  });
  await writeCriticalFile(targetName, css);
}

async function extractCriticalCSS() {
  if (!isProduction()) {
    console.log('Critical CSS generation skipped because environment is not production.');
    return;
  }

  const config = await readConfig();
  const { enabled, dimensions, penthouseOptions } = resolveCriticalSettings(config);

  if (!enabled) {
    console.log('Critical CSS generation skipped because it is disabled in _config.yml.');
    return;
  }

  await ensureIncludesDirectory();

  // Build inside the repo, not os.tmpdir(). The generated pages link the
  // stylesheet as an absolute href (/assets/css/main.css), and critical only
  // resolves those against paths at or under the working directory -- with a
  // base outside it the search list collapses to cwd and the lookup fails with
  // `File not found: /assets/css/main.css`. tmp/ is already gitignored.
  const scratchDir = path.join(rootDir, 'tmp');
  await fs.mkdir(scratchDir, { recursive: true });
  const tmpRoot = await fs.mkdtemp(path.join(scratchDir, 'critical-'));
  try {
    await buildSite(tmpRoot);

    const homeSrc = 'index.html';
    const defaultSrc = 'blog/index.html';
    const postSrc = await locateSamplePost(tmpRoot);

    const targets = [
      { targetName: 'home', src: homeSrc },
      { targetName: 'default', src: defaultSrc },
      { targetName: 'post', src: postSrc }
    ];

    for (const target of targets) {
      await extractCriticalForTarget({
        baseDir: tmpRoot,
        src: target.src,
        targetName: target.targetName,
        dimensions,
        penthouseOptions
      });
    }
  } finally {
    await fs.rm(tmpRoot, { recursive: true, force: true });
  }
}

extractCriticalCSS().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
