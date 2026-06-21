#!/usr/bin/env node
/**
 * Build Flutter web (release) puis déploie Firebase Hosting depuis build/web.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { verifierAuthFirebase } from './firebase-token.mjs';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const skipBuild = process.env.SKIP_FLUTTER_BUILD === '1';

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

function verifierBuild() {
  const fichiersRequis = [
    'index.html',
    'flutter_bootstrap.js',
    join('doc', 'index.html'),
  ];
  for (const fichier of fichiersRequis) {
    const chemin = join(buildDir, fichier);
    if (!existsSync(chemin)) {
      console.error(`\n✗ Fichier manquant dans build/web : ${fichier}`);
      console.error('  Vérifiez que flutter build web s’est terminé correctement.');
      process.exit(1);
    }
  }
}

console.log('Kelegance — déploiement web (Flutter + Firebase Hosting)');

if (skipBuild) {
  console.log('(SKIP_FLUTTER_BUILD=1 — build Flutter ignoré)');
} else {
  run('flutter', ['build', 'web', '--release'], 'flutter build web --release');
  run('node', ['scripts/inject-pwa-cache.mjs'], 'Injection service worker PWA Kelegance');
}

if (!existsSync(buildDir)) {
  console.error('\n✗ Dossier build/web introuvable après le build.');
  process.exit(1);
}

verifierBuild();
verifierAuthFirebase(root);

run('npx', ['firebase', 'deploy', '--only', 'hosting'], 'firebase deploy --only hosting');

console.log('\n✓ Déploiement terminé.');
console.log('  Application : https://cheerful-salamander-565dfc.netlify.app');
console.log('  QR client   : https://cheerful-salamander-565dfc.netlify.app/reserver');
console.log('  Test auto   : npm run test:deeplinks');
console.log('  Checklist   : docs/checklist-deep-links-pwa.md\n');
