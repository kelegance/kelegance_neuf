#!/usr/bin/env node
/**
 * @deprecated Utiliser prepare-web-build.mjs
 */
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';

const root = process.cwd();
console.warn('⚠ strip-service-worker.mjs est obsolète — redirection vers prepare-web-build.mjs');
const result = spawnSync('node', [join(root, 'scripts', 'prepare-web-build.mjs')], {
  cwd: root,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
process.exit(result.status ?? 1);
