#!/usr/bin/env node
/**
 * Vérifie que build/web est prêt pour Netlify (PWA versionnée + service worker Kelegance).
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const buildDir = join(process.cwd(), 'build', 'web');
const erreurs = [];

if (!existsSync(join(buildDir, 'index.html'))) {
  erreurs.push('build/web/index.html manquant (vitrine publique)');
}
if (!existsSync(join(buildDir, 'flutter_bootstrap.js'))) {
  erreurs.push('build/web/flutter_bootstrap.js manquant');
}
if (!existsSync(join(buildDir, 'flutter_service_worker.js'))) {
  erreurs.push('flutter_service_worker.js manquant — lancer prepare-web-build.mjs');
}
if (!existsSync(join(buildDir, 'version.json'))) {
  erreurs.push('version.json manquant — lancer prepare-web-build.mjs');
}
if (!existsSync(join(buildDir, 'kelegance-version-check.js'))) {
  erreurs.push('kelegance-version-check.js manquant — lancer prepare-web-build.mjs');
}

const bootstrapPath = join(buildDir, 'flutter_bootstrap.js');
if (existsSync(bootstrapPath)) {
  const bootstrap = readFileSync(bootstrapPath, 'utf8');
  if (!/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/.test(bootstrap)) {
    erreurs.push('flutter_bootstrap.js n’enregistre pas le service worker Kelegance');
  }
}

const indexPath = join(buildDir, 'index.html');
const appPath = join(buildDir, 'app.html');

if (!existsSync(appPath)) {
  erreurs.push('build/web/app.html manquant — lancez flutter build web + prepare-web-build.mjs');
}

if (existsSync(indexPath)) {
  const index = readFileSync(indexPath, 'utf8');
  if (!index.includes('data-kelegance-vitrine')) {
    erreurs.push('index.html n’est pas la vitrine publique (data-kelegance-vitrine manquant)');
  }
}

if (existsSync(appPath)) {
  const app = readFileSync(appPath, 'utf8');
  if (!app.includes('keleganceVerifierVersion')) {
    erreurs.push('app.html sans vérification de version PWA');
  }
}

const swPath = join(buildDir, 'flutter_service_worker.js');
if (existsSync(swPath)) {
  const sw = readFileSync(swPath, 'utf8');
  if (!sw.includes('BUILD_ID') && !sw.includes('kelegance-v')) {
    erreurs.push('service worker sans identifiant de version');
  }
}

if (erreurs.length > 0) {
  console.error('✗ Build web invalide pour déploiement Netlify :');
  for (const e of erreurs) console.error(`  • ${e}`);
  process.exit(1);
}

console.log('✓ Build web vérifié — PWA versionnée, prêt pour Netlify.');
