#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import path from 'node:path';
import process from 'node:process';
import url from 'node:url';
import waitOn from 'wait-on';

import { nodeBinArgs, spawnCompat } from './spawn_compat.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const siteDir = path.join(projectRoot, '_site');
const port = Number(process.env.PLAYWRIGHT_PORT || 4173);
const defaultBaseUrl = `http://127.0.0.1:${port}`;

function runCommand(command, args = [], options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawnCompat(command, args, {
      stdio: 'inherit',
      env: process.env,
      ...options,
    });
    child.on('error', reject);
    child.on('exit', (code, signal) => {
      if (signal) {
        const err = new Error(`Command terminated with signal ${signal}: ${command}`);
        err.exitCode = code ?? 1;
        return reject(err);
      }
      resolve(code ?? 0);
    });
  });
}

async function startServer() {
  console.log(`➡️  Serving _site on ${defaultBaseUrl}...`);
  const [nodeBinary, httpServerCli] = nodeBinArgs('http-server');
  const server = spawn(nodeBinary, [httpServerCli, siteDir, '-p', String(port), '--silent'], {
    stdio: 'inherit',
    env: process.env,
  });

  try {
    await waitOn({
      resources: [`http-get://127.0.0.1:${port}`],
      timeout: 20000,
      interval: 200,
    });
  } catch (error) {
    server.kill();
    throw new Error(`Static server failed to start on port ${port}: ${error.message}`);
  }

  return server;
}

async function main() {
  const playwrightArgs = process.argv.slice(2);
  const hasExternalBase = Boolean(process.env.PLAYWRIGHT_BASE_URL);
  let server;

  if (hasExternalBase) {
    console.log(
      `ℹ️  Detected PLAYWRIGHT_BASE_URL=${process.env.PLAYWRIGHT_BASE_URL}; skipping Jekyll build.`
    );
  } else {
    console.log('➡️  Building site with Jekyll...');
    const buildCode = await runCommand('bundle', ['exec', 'jekyll', 'build']);
    if (buildCode !== 0) {
      process.exit(buildCode);
    }
  }

  if (!hasExternalBase) {
    server = await startServer();
  } else {
    console.log('ℹ️  External PLAYWRIGHT_BASE_URL provided; skipping local server start.');
  }

  const env = {
    ...process.env,
    PLAYWRIGHT_BASE_URL: process.env.PLAYWRIGHT_BASE_URL || defaultBaseUrl,
  };

  console.log(`➡️  Running Playwright with PLAYWRIGHT_BASE_URL=${env.PLAYWRIGHT_BASE_URL}`);

  const [nodeBinary, playwrightCli] = nodeBinArgs('@playwright/test', 'playwright');
  let exitCode = 0;
  try {
    exitCode = await new Promise((resolve, reject) => {
      const child = spawn(nodeBinary, [playwrightCli, 'test', ...playwrightArgs], {
        stdio: 'inherit',
        env,
      });
      child.on('error', reject);
      child.on('exit', (code, signal) => {
        if (signal) {
          const err = new Error(`Playwright terminated with signal ${signal}`);
          err.exitCode = code ?? 1;
          return reject(err);
        }
        resolve(code ?? 0);
      });
    });
  } finally {
    if (server) {
      server.kill('SIGINT');
      await once(server, 'exit');
    }
  }

  process.exit(exitCode);
}

main().catch((error) => {
  console.error(error);
  process.exit(error.exitCode ?? 1);
});
