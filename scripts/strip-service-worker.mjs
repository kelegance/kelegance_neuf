#!/usr/bin/env node
/**
 * Désactive le service worker Flutter après `flutter build web` :
 * - retire serviceWorkerSettings de flutter_bootstrap.js
 * - supprime flutter_service_worker.js du build
 */
import { copyFileSync, existsSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const bootstrapPath = join(buildDir, 'flutter_bootstrap.js');
const swPath = join(buildDir, 'flutter_service_worker.js');

if (!existsSync(bootstrapPath)) {
  console.error('✗ build/web/flutter_bootstrap.js introuvable — lancez d’abord flutter build web');
  process.exit(1);
}

let bootstrap = readFileSync(bootstrapPath, 'utf8');

if (bootstrap.includes('serviceWorkerSettings')) {
  const sansSw = bootstrap.replace(
    /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:[\s\S]*?\}\);?\s*$/,
    '_flutter.loader.load({});\n',
  );

  if (/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/.test(sansSw)) {
    console.error('✗ Impossible de retirer serviceWorkerSettings de flutter_bootstrap.js');
    process.exit(1);
  }

  bootstrap = sansSw;
  writeFileSync(bootstrapPath, bootstrap, 'utf8');
  console.log('✓ flutter_bootstrap.js — enregistrement service worker retiré');
} else {
  console.log('✓ flutter_bootstrap.js — déjà sans service worker');
}

if (existsSync(swPath)) {
  unlinkSync(swPath);
  console.log('✓ flutter_service_worker.js supprimé');
} else {
  console.log('  (flutter_service_worker.js absent)');
}

for (const fichier of ['_headers', '_redirects']) {
  const src = join(root, 'web', fichier);
  const dest = join(buildDir, fichier);
  if (existsSync(src)) {
    copyFileSync(src, dest);
    console.log(`✓ ${fichier} copié dans build/web`);
  }
}
