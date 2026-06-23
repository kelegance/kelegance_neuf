#!/usr/bin/env node
/**
 * Vérifie que build/web est prêt pour Netlify (sans service worker ni cache PWA).
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const buildDir = join(process.cwd(), 'build', 'web');
const erreurs = [];

if (!existsSync(join(buildDir, 'index.html'))) {
  erreurs.push('build/web/index.html manquant');
}
if (!existsSync(join(buildDir, 'flutter_bootstrap.js'))) {
  erreurs.push('build/web/flutter_bootstrap.js manquant');
}
if (existsSync(join(buildDir, 'flutter_service_worker.js'))) {
  erreurs.push('flutter_service_worker.js encore présent — lancer strip-service-worker.mjs');
}

const bootstrapPath = join(buildDir, 'flutter_bootstrap.js');
if (existsSync(bootstrapPath)) {
  const bootstrap = readFileSync(bootstrapPath, 'utf8');
  if (/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/.test(bootstrap)) {
    erreurs.push('flutter_bootstrap.js enregistre encore un service worker');
  }
}

const indexPath = join(buildDir, 'index.html');
if (existsSync(indexPath)) {
  const index = readFileSync(indexPath, 'utf8');
  if (!index.includes('getRegistrations')) {
    erreurs.push('index.html sans script de nettoyage des anciens service workers');
  }
}

if (erreurs.length > 0) {
  console.error('✗ Build web invalide pour déploiement Netlify :');
  for (const e of erreurs) console.error(`  • ${e}`);
  process.exit(1);
}

console.log('✓ Build web vérifié — prêt pour Netlify (sans service worker).');
