#!/usr/bin/env node
/**
 * Déploiement production Kelegance — les deux canaux admin :
 *   • PWA (iPhone Safari / écran d'accueil)
 *   • APK Android (OTA via /releases/android-latest.json)
 *
 * Usage :
 *   npm run deploy:production
 *   npm run deploy:production -- --skip-apk    # PWA seulement (si Gradle indisponible)
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { preparerEnvironnementFirebase } from './firebase-env.mjs';

preparerEnvironnementFirebase();

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const skipApk = process.argv.includes('--skip-apk');
const webOrigin = process.env.KELEGANCE_WEB_ORIGIN || 'https://kelegance.web.app';
const googleMapsKey =
  process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI';

const dartDefines = [
  `--dart-define=KELEGANCE_WEB_ORIGIN=${webOrigin}`,
  `--dart-define=GOOGLE_MAPS_API_KEY=${googleMapsKey}`,
];

function run(command, args, label, { optional = false } = {}) {
  console.log(`\n▶ ${label}`);
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env: { ...process.env, KELEGANCE_WEB_ORIGIN: webOrigin },
  });
  if (result.status !== 0) {
    if (optional) {
      console.warn(`\n⚠ Ignoré (optionnel) : ${label}`);
      return false;
    }
    console.error(`\n✗ Échec : ${label}`);
    process.exit(result.status ?? 1);
  }
  return true;
}

function lireVersion() {
  const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([0-9.]+)\+(\d+)/m);
  if (!match) return { version: '?', buildNumber: 0 };
  return { version: match[1], buildNumber: Number.parseInt(match[2], 10) };
}

console.log('╔══════════════════════════════════════════════════════════╗');
console.log('║  Kelegance — Déploiement production (PWA + APK Android)  ║');
console.log('╚══════════════════════════════════════════════════════════╝');
console.log(`\nOrigine : ${webOrigin}\n`);

run(
  'flutter',
  ['build', 'web', '--release', ...dartDefines],
  'Build PWA (Flutter web)',
);

run('node', ['scripts/prepare-web-build.mjs'], 'Préparation PWA (service worker + version.json)');

if (skipApk) {
  console.log('\n⏭ APK ignoré (--skip-apk)');
} else {
  const apkOk = run(
    'node',
    ['scripts/publish-android-release.mjs'],
    'Build APK Android + manifeste OTA',
    { optional: true },
  );
  if (!apkOk) {
    console.warn('\n⚠ APK non compilé — les admins Android restent sur leur version actuelle.');
    console.warn('  Relancez plus tard : npm run deploy:android');
    console.warn('  puis : npm run deploy:hosting:firebase\n');
  }
}

if (!existsSync(join(buildDir, 'index.html'))) {
  console.error('\n✗ build/web/index.html introuvable.');
  process.exit(1);
}

run('npx', ['firebase', 'deploy', '--only', 'hosting'], 'Firebase Hosting (PWA + releases/)');

const { version, buildNumber } = lireVersion();

console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║  ✓ Déploiement terminé                                   ║');
console.log('╚══════════════════════════════════════════════════════════╝');
console.log(`\n  Version : ${version} (build ${buildNumber})`);
console.log(`  BuildId : v${version}-b${buildNumber}\n`);

console.log('── iPhone (PWA) — Safari ou icône écran d\'accueil ─────────');
console.log(`  Bras Droit  : ${webOrigin}/gestion?profil=bras_droit&v=${version}`);
console.log(`  Chauffeur   : ${webOrigin}/chauffeur?role=driver&v=${version}`);
console.log(`  Forcer MAJ  : ajouter &v=${version} ou &refresh=1 à l\'URL\n`);

console.log('── Android (APK natif) ────────────────────────────────────');
console.log(`  OTA auto    : Paramètres → Vérifier les mises à jour`);
console.log(`  APK direct  : ${webOrigin}/releases/kelegance-latest.apk`);
console.log(`  Manifeste   : ${webOrigin}/releases/android-latest.json\n`);

console.log('── Vérification ───────────────────────────────────────────');
console.log(`  npm run test:deeplinks -- --origin ${webOrigin}\n`);
