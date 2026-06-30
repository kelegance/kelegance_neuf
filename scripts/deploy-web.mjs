#!/usr/bin/env node
/**
 * Build Flutter web (release) puis déploie Firebase Hosting depuis build/web.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { chargerTokenFirebase } from './firebase-token.mjs';
import { preparerEnvironnementFirebase } from './firebase-env.mjs';

preparerEnvironnementFirebase();

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
  const webOrigin = process.env.KELEGANCE_WEB_ORIGIN || 'https://kelegance.web.app';
  const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI';
  run(
    'flutter',
    [
      'build',
      'web',
      '--release',
      `--dart-define=KELEGANCE_WEB_ORIGIN=${webOrigin}`,
      `--dart-define=GOOGLE_MAPS_API_KEY=${googleMapsKey}`,
    ],
    'flutter build web --release',
  );
  run('node', ['scripts/prepare-web-build.mjs'], 'Préparation PWA (version + service worker)');
}

if (!existsSync(buildDir)) {
  console.error('\n✗ Dossier build/web introuvable après le build.');
  process.exit(1);
}

verifierBuild();

if (chargerTokenFirebase(root)) {
  console.log('✓ Authentification Firebase CI (token chargé)');
} else {
  console.log('(Token CI absent — utilisation des identifiants Firebase locaux)');
}

run('npx', ['firebase', 'deploy', '--only', 'hosting'], 'firebase deploy --only hosting');

console.log('\n✓ Déploiement PWA terminé.');
console.log('  Application : https://kelegance.web.app');
console.log('  iPhone PWA  : https://kelegance.web.app/gestion?profil=bras_droit');
console.log('  Android APK : npm run deploy:android && npm run deploy:hosting:firebase');
console.log('  Test auto   : npm run test:deeplinks\n');
