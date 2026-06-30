#!/usr/bin/env node
/**
 * Prépare build/web pour déploiement PWA :
 * - version.json (buildId v{version}-b{buildNumber})
 * - service worker Kelegance versionné (cache invalidé à chaque build)
 * - hub/sw.js versionné
 * - assets statiques (hub, print, doc, _headers, _redirects)
 */
import { createHash } from 'node:crypto';
import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const templatePath = join(root, 'web', 'kelegance-service-worker.template.js');
const hubSwTemplate = join(root, 'web', 'hub', 'sw.template.js');
const swOutputPath = join(buildDir, 'flutter_service_worker.js');

const ROUTES_SPA = ['/app.html', '/reserver', '/gestion', '/chauffeur', '/admin/qrcodes', '/console'];

const FICHIERS_INTERDITS = ['admin_dashboard.apk'];

const EXCLUDED = new Set([
  'flutter_service_worker.js',
  'kelegance-service-worker.js',
  '.last_build_id',
]);

function buildIdDepuisPubspec(meta) {
  return `v${meta.version}-b${meta.buildNumber}`;
}

function lirePubspec() {
  const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([0-9.]+)\+(\d+)/m);
  if (!match) return { version: '0.0.0', buildNumber: 0 };
  return { version: match[1], buildNumber: Number.parseInt(match[2], 10) };
}

function toUrlPath(relativePath) {
  return `/${relativePath.split('\\').join('/')}`;
}

function walkFiles(dir, base = buildDir) {
  const entries = readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkFiles(full, base));
      continue;
    }
    if (!entry.isFile()) continue;
    const relativePath = relative(base, full);
    if (EXCLUDED.has(relativePath.split('\\').join('/'))) continue;
    files.push(toUrlPath(relativePath));
  }
  return files;
}

function buildPrecacheList() {
  const files = walkFiles(buildDir);
  const urls = new Set([...ROUTES_SPA, ...files]);
  return [...urls].sort();
}

function cacheNameFromUrls(urls, buildId) {
  const hash = createHash('sha256').update(urls.join('|')).digest('hex').slice(0, 10);
  return `kelegance-${buildId}-${hash}`;
}

function renderServiceWorker(urls, buildId) {
  const template = readFileSync(templatePath, 'utf8');
  const cacheName = cacheNameFromUrls(urls, buildId);
  return template
    .replace('%%CACHE_NAME%%', cacheName)
    .replace('%%BUILD_ID%%', buildId)
    .replace('%%PRECACHE_URLS%%', JSON.stringify(urls, null, 2));
}

function patchBootstrapVersion(swContent) {
  const bootstrapPath = join(buildDir, 'flutter_bootstrap.js');
  if (!existsSync(bootstrapPath)) return;

  let content = readFileSync(bootstrapPath, 'utf8');
  const version = createHash('sha256').update(swContent).digest('hex').slice(0, 10);

  if (content.includes('serviceWorkerVersion:')) {
    content = content.replace(/serviceWorkerVersion:\s*"[^"]*"/, `serviceWorkerVersion: "${version}"`);
  }

  if (!content.includes('serviceWorkerSettings')) {
    content = content.replace(
      '_flutter.loader.load({});',
      `_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "${version}",
  },
});`,
    );
    content = content.replace(
      '_flutter.loader.load({})',
      `_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "${version}",
  },
})`,
    );
  }

  writeFileSync(bootstrapPath, content, 'utf8');
  console.log(`✓ flutter_bootstrap.js — serviceWorkerVersion=${version}`);
}

function genererVersionJson(buildId, meta) {
  const payload = {
    buildId,
    version: meta.version,
    buildNumber: meta.buildNumber,
    publishedAt: new Date().toISOString(),
  };
  writeFileSync(join(buildDir, 'version.json'), `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`✓ version.json — buildId=${buildId}`);
  return payload;
}

function genererHubServiceWorker(buildId) {
  if (!existsSync(hubSwTemplate)) {
    console.warn('  (hub/sw.template.js absent — ignoré)');
    return;
  }
  const sw = readFileSync(hubSwTemplate, 'utf8').replace(/%%BUILD_ID%%/g, buildId);
  const hubDir = join(buildDir, 'hub');
  mkdirSync(hubDir, { recursive: true });
  writeFileSync(join(hubDir, 'sw.js'), sw, 'utf8');
  writeFileSync(join(root, 'web', 'hub', 'sw.js'), sw, 'utf8');
  console.log(`✓ hub/sw.js — BUILD_ID=${buildId}`);
}

function purgerFichiersSensibles() {
  for (const nom of FICHIERS_INTERDITS) {
    const racine = join(buildDir, nom);
    const releases = join(buildDir, 'releases', nom);
    for (const chemin of [racine, releases]) {
      if (existsSync(chemin)) {
        unlinkSync(chemin);
        console.log(`✓ ${nom} supprimé de build/web (accès public interdit)`);
      }
    }
  }
}

function installerVitrineEtApp() {
  const flutterShell = join(buildDir, 'index.html');
  const appShell = join(buildDir, 'app.html');
  const vitrineSrc = join(root, 'web', 'vitrine.html');
  const vitrineDest = join(buildDir, 'index.html');

  if (!existsSync(vitrineSrc)) {
    console.error('✗ web/vitrine.html introuvable');
    process.exit(1);
  }

  if (existsSync(flutterShell)) {
    const contenu = readFileSync(flutterShell, 'utf8');
    if (contenu.includes('flutter_bootstrap.js')) {
      copyFileSync(flutterShell, appShell);
      console.log('✓ Shell Flutter → app.html');
    }
  }

  if (!existsSync(appShell)) {
    console.error('✗ app.html manquant — lancez d’abord flutter build web');
    process.exit(1);
  }

  copyFileSync(vitrineSrc, vitrineDest);
  console.log('✓ Vitrine publique → index.html');
}

function copierAssetsStatiques() {
  for (const fichier of ['_headers', '_redirects', 'kelegance-version-check.js']) {
    const src = join(root, 'web', fichier);
    const dest = join(buildDir, fichier);
    if (existsSync(src)) {
      copyFileSync(src, dest);
      console.log(`✓ ${fichier} copié dans build/web`);
    }
  }

  for (const dossier of ['hub', 'print', 'doc']) {
    const srcDir = join(root, 'web', dossier);
    const destDir = join(buildDir, dossier);
    if (!existsSync(srcDir)) continue;
    cpSync(srcDir, destDir, { recursive: true });
    console.log(`✓ ${dossier}/ copié dans build/web`);
  }
}

function genererWebLatest(meta) {
  const releasesDir = join(buildDir, 'releases');
  mkdirSync(releasesDir, { recursive: true });
  writeFileSync(
    join(releasesDir, 'web-latest.json'),
    `${JSON.stringify({
      version: meta.version,
      buildNumber: meta.buildNumber,
      publishedAt: new Date().toISOString(),
    }, null, 2)}\n`,
    'utf8',
  );
  console.log('✓ releases/web-latest.json généré');
}

function main() {
  if (!existsSync(buildDir)) {
    console.error('✗ build/web introuvable — lancez d’abord flutter build web');
    process.exit(1);
  }
  if (!existsSync(templatePath)) {
    console.error('✗ Template introuvable : web/kelegance-service-worker.template.js');
    process.exit(1);
  }

  const meta = lirePubspec();
  const buildId = buildIdDepuisPubspec(meta);

  copierAssetsStatiques();

  purgerFichiersSensibles();
  installerVitrineEtApp();

  genererVersionJson(buildId, meta);

  const urls = buildPrecacheList();
  const sw = renderServiceWorker(urls, buildId);
  writeFileSync(swOutputPath, sw, 'utf8');
  writeFileSync(join(buildDir, 'kelegance-service-worker.js'), sw, 'utf8');
  console.log(`✓ Service worker PWA Kelegance (${urls.length} URLs precache, cache invalidé par build)`);

  patchBootstrapVersion(sw);
  genererHubServiceWorker(buildId);
  genererWebLatest(meta);
  synchroniserManifesteAndroid(meta);
  synchroniserApkReleases(meta);
}

function synchroniserManifesteAndroid(meta) {
  const source = join(root, 'releases', 'android-latest.json');
  const dest = join(buildDir, 'releases', 'android-latest.json');
  if (existsSync(source)) {
    copyFileSync(source, dest);
    console.log('✓ releases/android-latest.json synchronisé');
    return;
  }
  const payload = {
    version: meta.version,
    buildNumber: meta.buildNumber,
    apkUrl: `https://kelegance.web.app/releases/kelegance-latest.apk`,
    releaseNotes: 'Mise à jour Kelegance — correctifs et améliorations.',
    mandatory: false,
    publishedAt: new Date().toISOString(),
  };
  mkdirSync(join(buildDir, 'releases'), { recursive: true });
  writeFileSync(dest, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`✓ releases/android-latest.json généré (v${meta.version} b${meta.buildNumber})`);
}

function synchroniserApkReleases(meta) {
  const releasesRepo = join(root, 'releases');
  const releasesBuild = join(buildDir, 'releases');
  mkdirSync(releasesBuild, { recursive: true });

  const apkSource = join(root, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
  const apkVersionne = `kelegance-${meta.version}.apk`;

  function copierApk(src, destLabel) {
    if (!existsSync(src)) return false;
    const latest = join(releasesBuild, 'kelegance-latest.apk');
    const versionne = join(releasesBuild, apkVersionne);
    copyFileSync(src, latest);
    copyFileSync(src, versionne);
    console.log(`✓ releases/${destLabel} → kelegance-latest.apk + ${apkVersionne}`);
    return true;
  }

  if (copierApk(join(releasesRepo, 'kelegance-latest.apk'), 'kelegance-latest.apk (repo)')) {
    return;
  }
  if (copierApk(join(releasesRepo, apkVersionne), apkVersionne)) {
    return;
  }
  if (copierApk(apkSource, 'app-release.apk')) {
    return;
  }
  console.warn('⚠ APK OTA absent — lancez npm run deploy:android avant le déploiement hosting.');
}

main();
