#!/usr/bin/env node
/**
 * Déploie uniquement Firebase Hosting (sans rebuild Flutter).
 * Utile après correction d'auth quand build/web existe déjà.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { verifierAuthFirebase } from './firebase-token.mjs';

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

console.log('Kelegance — déploiement Hosting uniquement');

if (!existsSync(join(buildDir, 'index.html'))) {
  console.error('\n✗ build/web/index.html introuvable.');
  console.error('  Lancez d\'abord : npm run deploy:web');
  console.error('  Ou : flutter build web --release');
  process.exit(1);
}

verifierAuthFirebase(root);
run('npx', ['firebase', 'deploy', '--only', 'hosting'], 'firebase deploy --only hosting');

console.log('\n✓ Hosting déployé.');
console.log('  https://cheerful-salamander-565dfc.netlify.app/reserver\n');
