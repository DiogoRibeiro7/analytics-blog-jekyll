import { fileURLToPath } from 'url';
import path from 'path';
import os from 'os';
import fs from 'fs/promises';
import { spawn } from 'child_process';
import YAML from 'yaml';
import critical from 'critical';

const { generate } = critical;

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
    const child = spawn(command, args, {
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
  const blogDir = path.resolve(buildDir, 'blog');
  try {
    const stat = await fs.stat(blogDir);
    if (!stat.isDirectory()) {
      throw new Error('Blog directory is not a directory');
    }
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error('Blog directory not found in generated site');
    }
    throw error;
  }

  const stack = [blogDir];
  while (stack.length > 0) {
    const current = stack.pop();
    const entries = await fs.readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.resolve(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(entryPath);
      } else if (entry.isFile() && entry.name === 'index.html') {
        const relative = path.relative(buildDir, entryPath).replace(/\\/g, '/');
        if (relative.toLowerCase() !== 'blog/index.html') {
          return relative;
        }
      }
    }
  }

  throw new Error('Unable to locate a generated blog post to extract critical CSS');
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
    src,
    inline: false,
    dimensions,
    minify: true,
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

  const tmpRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'jekyll-critical-'));
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
