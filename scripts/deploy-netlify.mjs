#!/usr/bin/env node
/**
 * Build Flutter web (release) puis déploie sur Netlify depuis build/web.
 *
 * Prérequis :
 *   - `netlify login` ou variable NETLIFY_AUTH_TOKEN
 *   - Site lié (.netlify/state.json) ou NETLIFY_SITE_ID / --site
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const skipBuild = process.env.SKIP_FLUTTER_BUILD === '1';
const webOrigin =
  process.env.KELEGANCE_WEB_ORIGIN ||
  process.env.URL ||
  'https://cheerful-salamander-565dfc.netlify.app';
const googleMapsKey =
  process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI';
const netlifySite = process.env.NETLIFY_SITE_ID || 'cheerful-salamander-565dfc';

function run(command, args, label, env = process.env) {
  console.log(`\n▶ ${label}`);
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env,
  });
  if (result.status !== 0) {
    console.error(`\n✗ Échec : ${label}`);
    process.exit(result.status ?? 1);
  }
}

console.log('Kelegance — déploiement web (Flutter + Netlify)');
console.log(`  Origine : ${webOrigin}`);

if (skipBuild) {
  console.log('(SKIP_FLUTTER_BUILD=1 — build Flutter ignoré)');
} else {
  run('flutter', ['pub', 'get'], 'flutter pub get');
  run(
    'flutter',
    [
      'build',
      'web',
      '--release',
      '--base-href=/',
      `--dart-define=KELEGANCE_WEB_ORIGIN=${webOrigin}`,
      `--dart-define=GOOGLE_MAPS_API_KEY=${googleMapsKey}`,
    ],
    'flutter build web --release',
  );
  run('node', ['scripts/strip-service-worker.mjs'], 'Désactivation service worker');
}

if (!existsSync(buildDir)) {
  console.error('\n✗ Dossier build/web introuvable après le build.');
  process.exit(1);
}

run('node', ['scripts/verify-web-build.mjs'], 'Vérification build sans SW');

const netlifyBin =
  process.platform === 'win32'
    ? join(root, 'node_modules', '.bin', 'netlify.cmd')
    : join(root, 'node_modules', '.bin', 'netlify');

if (existsSync(netlifyBin)) {
  run(netlifyBin, ['deploy', '--prod', '--dir=build/web', `--site=${netlifySite}`], 'netlify deploy --prod');
} else if (process.env.NETLIFY_AUTH_TOKEN) {
  run('node', ['scripts/netlify-deploy-zip.mjs'], 'Déploiement Netlify via API (zip)');
} else {
  console.error('\n✗ Netlify CLI absent et NETLIFY_AUTH_TOKEN non défini.');
  console.error('  Option A : npm install netlify-cli --save-dev && npx netlify login');
  console.error('  Option B : définir NETLIFY_AUTH_TOKEN puis relancer npm run deploy:netlify');
  console.error('  Option C : git push origin master (build Netlify CI si le dépôt est connecté)\n');
  process.exit(1);
}

console.log('\n✓ Déploiement Netlify terminé.');
console.log(`  Application : ${webOrigin}`);
console.log(`  QR client   : ${webOrigin}/reserver`);
console.log(`  Bras Droit  : ${webOrigin}/gestion`);
console.log('  Test auto   : npm run test:deeplinks\n');
