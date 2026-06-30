#!/usr/bin/env node
/**
 * Prépare dist/apk-server/ — dossier prêt à uploader sur Apache (FTP/SFTP).
 * Copie index.html, .htaccess, logo, manifeste et APK public.
 */
import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const srcDir = join(root, 'server-root');
const outDir = join(root, 'dist', 'apk-server');
const releasesSrc = join(root, 'releases');
const logoSrc = join(root, 'assets', 'images', 'kelegance_logo.png');

function copierSiExiste(src, dest) {
  if (!existsSync(src)) return false;
  mkdirSync(join(dest, '..'), { recursive: true });
  copyFileSync(src, dest);
  return true;
}

if (!existsSync(srcDir)) {
  console.error('\n✗ server-root/ introuvable.\n');
  process.exit(1);
}

if (existsSync(outDir)) {
  rmSync(outDir, { recursive: true, force: true });
}
mkdirSync(outDir, { recursive: true });

cpSync(srcDir, outDir, {
  recursive: true,
  filter: (src) => !src.endsWith('.htpasswd'),
});

mkdirSync(join(outDir, 'assets'), { recursive: true });
mkdirSync(join(outDir, 'releases'), { recursive: true });

if (!copierSiExiste(logoSrc, join(outDir, 'assets', 'kelegance_logo.png'))) {
  console.warn('⚠ Logo introuvable — ajoutez assets/kelegance_logo.png manuellement.');
}

copierSiExiste(join(releasesSrc, 'android-latest.json'), join(outDir, 'releases', 'android-latest.json'));

function copierApkPublic() {
  const manifestPath = join(releasesSrc, 'android-latest.json');
  if (existsSync(manifestPath)) {
    try {
      const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
      const nom = manifest.apkUrl?.split('/').pop();
      if (nom && copierSiExiste(join(releasesSrc, nom), join(outDir, 'releases', nom))) {
        copyFileSync(join(outDir, 'releases', nom), join(outDir, 'releases', 'kelegance-latest.apk'));
        console.log(`✓ releases/${nom} → kelegance-latest.apk`);
        return;
      }
    } catch {
      /* manifeste illisible */
    }
  }

  const apkLatest = join(releasesSrc, 'kelegance-latest.apk');
  if (copierSiExiste(apkLatest, join(outDir, 'releases', 'kelegance-latest.apk'))) {
    console.log('✓ releases/kelegance-latest.apk copié');
    return;
  }

  console.warn('⚠ APK public absent — lancez npm run deploy:android ou copiez l\'APK dans releases/.');
}

copierApkPublic();

const htpasswd = join(srcDir, '.htpasswd');
if (existsSync(htpasswd)) {
  copyFileSync(htpasswd, join(outDir, '.htpasswd'));
  console.log('✓ .htpasswd inclus (équipe admin)');
} else {
  console.warn('⚠ .htpasswd absent — npm run gen:htpasswd -- equipe VotreMotDePasse');
}

console.log(`\n✓ Dossier prêt : ${outDir}`);
console.log('  Uploadez tout le contenu à la racine de votre serveur Apache.');
console.log('  Placez admin_dashboard.apk à la racine (protégé par Basic Auth).\n');
