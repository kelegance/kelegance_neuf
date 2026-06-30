#!/usr/bin/env node
/**
 * Compile l'APK release, publie le manifeste OTA et l'APK sur build/web/releases/, puis déploie Netlify.
 *
 * Usage :
 *   npm run deploy:android          # build APK + manifeste (sans upload Netlify)
 *   npm run deploy:android:ota      # build + upload Netlify (APK + manifeste + web si présent)
 */
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const buildWebDir = join(root, 'build', 'web');
const releasesDir = join(buildWebDir, 'releases');
const apkSource = join(root, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const deployNetlify = process.argv.includes('--deploy');

const webOrigin =
  process.env.KELEGANCE_WEB_ORIGIN ||
  process.env.URL ||
  'https://kelegance.web.app';
const googleMapsKey =
  process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI';

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

function lireVersionPubspec() {
  const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([0-9.]+)\+(\d+)/m);
  if (!match) {
    throw new Error('Impossible de lire version: x.y.z+build dans pubspec.yaml');
  }
  return { version: match[1], buildNumber: Number.parseInt(match[2], 10) };
}

function notesDepuisArgs() {
  const idx = process.argv.indexOf('--notes');
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  return 'Mise à jour Kelegance — correctifs et améliorations.';
}

console.log('Kelegance — publication APK OTA Android');
console.log(`  Origine : ${webOrigin}`);

run('flutter', ['pub', 'get'], 'flutter pub get');
run(
  'flutter',
  [
    'build',
    'apk',
    '--release',
    `--dart-define=KELEGANCE_WEB_ORIGIN=${webOrigin}`,
    `--dart-define=GOOGLE_MAPS_API_KEY=${googleMapsKey}`,
  ],
  'flutter build apk --release',
);

if (!existsSync(apkSource)) {
  console.error(`\n✗ APK introuvable : ${apkSource}`);
  process.exit(1);
}

const { version, buildNumber } = lireVersionPubspec();
const apkName = `kelegance-${version}.apk`;
const apkDest = join(releasesDir, apkName);
const apkLatest = join(releasesDir, 'kelegance-latest.apk');
const manifestPath = join(releasesDir, 'android-latest.json');
// URL pérenne : kelegance-latest.apk est recopié à chaque release (évite les 404 sur le nom versionné).
const apkUrl = `${webOrigin}/releases/kelegance-latest.apk`;

mkdirSync(releasesDir, { recursive: true });
copyFileSync(apkSource, apkDest);
copyFileSync(apkSource, apkLatest);

const manifest = {
  version,
  buildNumber,
  apkUrl,
  releaseNotes: notesDepuisArgs(),
  mandatory: false,
  publishedAt: new Date().toISOString(),
};

writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

// Miroir dans releases/ (suivi repo + prepare-web-build sans rebuild APK).
const releasesRepo = join(root, 'releases');
mkdirSync(releasesRepo, { recursive: true });
copyFileSync(apkDest, join(releasesRepo, apkName));
copyFileSync(apkLatest, join(releasesRepo, 'kelegance-latest.apk'));
writeFileSync(join(releasesRepo, 'android-latest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

const webManifestPath = join(releasesDir, 'web-latest.json');
writeFileSync(
  webManifestPath,
  `${JSON.stringify({ version, buildNumber, publishedAt: manifest.publishedAt }, null, 2)}\n`,
  'utf8',
);

console.log('\n✓ Release OTA préparée :');
console.log(`  Manifeste : ${manifestPath}`);
console.log(`  APK       : ${apkDest}`);
console.log(`  URL       : ${apkUrl}`);

if (deployNetlify) {
  if (!existsSync(join(buildWebDir, 'app.html')) && !existsSync(join(buildWebDir, 'index.html'))) {
    console.log('\n▶ Build web absent — compilation Flutter web pour déploiement complet…');
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
    run('node', ['scripts/prepare-web-build.mjs'], 'Préparation PWA (version + service worker)');
    // Recopier releases après rebuild web (le dossier build/web peut être régénéré)
    mkdirSync(releasesDir, { recursive: true });
    copyFileSync(apkSource, apkDest);
    copyFileSync(apkSource, apkLatest);
    writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
    writeFileSync(
      join(releasesDir, 'web-latest.json'),
      `${JSON.stringify({ version, buildNumber, publishedAt: new Date().toISOString() }, null, 2)}\n`,
      'utf8',
    );
  }

  run('node', ['scripts/verify-web-build.mjs'], 'Vérification build web');
  run('node', ['scripts/deploy-netlify.mjs'], 'Déploiement Netlify', {
    ...process.env,
    SKIP_FLUTTER_BUILD: '1',
  });
} else {
  console.log('\nPour publier sur Netlify : npm run deploy:android:ota');
  console.log('(Assurez-vous que build/web contient aussi la version web, ou utilisez deploy:android:ota)\n');
}
