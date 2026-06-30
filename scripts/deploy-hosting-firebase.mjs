#!/usr/bin/env node
/**
 * Déploie Firebase Hosting sans rebuild (build/web doit exister).
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { preparerEnvironnementFirebase } from './firebase-env.mjs';

preparerEnvironnementFirebase();

const root = process.cwd();
const buildDir = join(root, 'build', 'web');

function run(command, args, label) {
  console.log(`\n▶ ${label}`);
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env: process.env,
  });
  if (result.status !== 0) {
    console.error(`\n✗ Échec : ${label}`);
    process.exit(result.status ?? 1);
  }
}

if (!existsSync(join(buildDir, 'index.html'))) {
  console.error('\n✗ build/web/index.html introuvable — lancez npm run deploy:production');
  process.exit(1);
}

run('npx', ['firebase', 'deploy', '--only', 'hosting'], 'firebase deploy --only hosting');
console.log('\n✓ Hosting Firebase déployé — https://kelegance.web.app\n');
