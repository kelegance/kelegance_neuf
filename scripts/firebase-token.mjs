import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Charge FIREBASE_TOKEN depuis l'environnement ou .firebase-token.local (gitignored).
 */
export function chargerTokenFirebase(rootDir = process.cwd()) {
  if (process.env.FIREBASE_TOKEN?.trim()) {
    return process.env.FIREBASE_TOKEN.trim();
  }

  const tokenFile = join(rootDir, '.firebase-token.local');
  if (!existsSync(tokenFile)) return null;

  const token = readFileSync(tokenFile, 'utf8').trim();
  if (!token) return null;

  process.env.FIREBASE_TOKEN = token;
  return token;
}

export function verifierAuthFirebase(rootDir = process.cwd()) {
  const token = chargerTokenFirebase(rootDir);
  if (token) {
    console.log('✓ Authentification Firebase CI (token chargé)');
    return token;
  }

  console.error('\n✗ Aucun token Firebase valide.');
  console.error('');
  console.error('  1. Ouvrez un terminal interactif dans Cursor (Ctrl+`)');
  console.error('  2. Exécutez : npm run firebase:login-ci');
  console.error('  3. Suivez le lien --no-localhost dans votre navigateur');
  console.error('  4. Relancez : npm run deploy:web');
  console.error('');
  console.error('  Alternative : définissez FIREBASE_TOKEN dans votre session PowerShell.');
  process.exit(1);
}
