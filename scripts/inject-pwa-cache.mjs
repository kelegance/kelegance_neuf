#!/usr/bin/env node
/**
 * Injecte un service worker de cache PWA dans build/web après `flutter build web`.
 * Remplace le flutter_service_worker.js "cleanup" (sans cache) par la version Kelegance.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const templatePath = join(root, 'web', 'kelegance-service-worker.template.js');
const outputPath = join(buildDir, 'flutter_service_worker.js');

const ROUTES_SPA = ['/app.html', '/reserver', '/gestion', '/chauffeur', '/admin/qrcodes', '/console'];

const EXCLUDED = new Set([
  'flutter_service_worker.js',
  'kelegance-service-worker.js',
  '.last_build_id',
]);

function toUrlPath(relativePath) {
  return '/' + relativePath.split('\\').join('/');
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
  if (!existsSync(buildDir)) {
    throw new Error('build/web introuvable — lancez d’abord flutter build web');
  }
  const files = walkFiles(buildDir);
  const urls = new Set([...ROUTES_SPA, ...files]);
  return [...urls].sort();
}

function cacheNameFromUrls(urls) {
  const hash = createHash('sha256').update(urls.join('|')).digest('hex').slice(0, 12);
  return `kelegance-precache-${hash}`;
}

function renderServiceWorker(urls) {
  const template = readFileSync(templatePath, 'utf8');
  const cacheName = cacheNameFromUrls(urls);
  return template
    .replace('%%CACHE_NAME%%', cacheName)
    .replace('%%PRECACHE_URLS%%', JSON.stringify(urls, null, 2));
}

function patchBootstrapVersion() {
  const bootstrapPath = join(buildDir, 'flutter_bootstrap.js');
  if (!existsSync(bootstrapPath)) return;

  const content = readFileSync(bootstrapPath, 'utf8');
  const swContent = readFileSync(outputPath, 'utf8');
  const version = createHash('sha256').update(swContent).digest('hex').slice(0, 10);

  const patched = content.replace(
    /serviceWorkerVersion:\s*"[0-9]+"/,
    `serviceWorkerVersion: "${version}"`,
  );

  if (patched !== content) {
    writeFileSync(bootstrapPath, patched, 'utf8');
    console.log(`✓ flutter_bootstrap.js — serviceWorkerVersion=${version}`);
  }
}

function main() {
  if (!existsSync(templatePath)) {
    console.error('✗ Template introuvable : web/kelegance-service-worker.template.js');
    process.exit(1);
  }

  const urls = buildPrecacheList();
  const sw = renderServiceWorker(urls);
  writeFileSync(outputPath, sw, 'utf8');

  // Copie lisible pour debug / inspection.
  writeFileSync(join(buildDir, 'kelegance-service-worker.js'), sw, 'utf8');

  patchBootstrapVersion();

  console.log(`✓ Service worker PWA Kelegance injecté (${urls.length} URLs en precache)`);
  console.log(`  → ${outputPath}`);
}

main();
