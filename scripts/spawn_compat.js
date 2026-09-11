/**
 * @fileoverview Cross-platform process spawning for the build and test scripts.
 *
 * Two Windows problems this solves:
 *
 * 1. Launchers such as `bundle`, or anything in `node_modules/.bin`, are
 *    `.bat`/`.cmd` scripts on Windows rather than executables. `spawn()` cannot
 *    run them directly: it fails with ENOENT when no extension is given, and
 *    Node refuses a `.cmd` path outright with EINVAL. The usual workaround,
 *    `spawn(..., { shell: true })`, runs them but concatenates the arguments
 *    into one command line without quoting, so an argument containing a space
 *    is silently split. `spawnCompat` invokes the command interpreter itself
 *    and lets Node quote each argument, which keeps spaces intact.
 * 2. A package's `.bin` shim exists only to locate an interpreter. For packages
 *    installed with this project the JavaScript entry point can be resolved
 *    directly, so `nodeBinArgs` returns it to run under the current Node
 *    binary: no launcher, no interpreter lookup, and no shell on any platform.
 */

import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import path from 'node:path';
import process from 'node:process';
import url from 'node:url';

const projectRoot = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const requireFromProject = createRequire(path.join(projectRoot, 'package.json'));

/**
 * Spawns a command, tolerating Windows script launchers.
 *
 * @param {string} command Executable or launcher name.
 * @param {string[]} [args] Arguments, which may contain spaces.
 * @param {object} [options] Options forwarded to child_process.spawn.
 * @returns {import('node:child_process').ChildProcess} The spawned process.
 */
export function spawnCompat(command, args = [], options = {}) {
  if (process.platform !== 'win32') {
    return spawn(command, args, options);
  }

  const comspec = process.env.ComSpec || 'cmd.exe';
  return spawn(comspec, ['/d', '/s', '/c', command, ...args], options);
}

/**
 * Resolves a dependency's command-line entry point so it can run under the
 * current Node binary instead of its platform-specific launcher.
 *
 * @param {string} packageName Package that provides the command.
 * @param {string} [binName] Name of the binary, when the package ships several.
 * @returns {string[]} Arguments for spawn: the Node binary followed by the script.
 */
export function nodeBinArgs(packageName, binName = packageName) {
  const manifest = requireFromProject(`${packageName}/package.json`);
  const entry = typeof manifest.bin === 'string' ? manifest.bin : manifest.bin?.[binName];

  if (!entry) {
    throw new Error(`Package ${packageName} does not provide a "${binName}" binary.`);
  }

  const packageDir = path.dirname(requireFromProject.resolve(`${packageName}/package.json`));
  return [process.execPath, path.resolve(packageDir, entry)];
}

export { projectRoot };
