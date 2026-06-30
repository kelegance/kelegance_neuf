#!/usr/bin/env node
/**
 * Génère server-root/.htpasswd pour Basic Auth Apache (admin_dashboard.apk).
 *
 * Usage :
 *   npm run gen:htpasswd -- equipe MonMotDePasseSecret
 *   node scripts/gen-htpasswd.mjs equipe MonMotDePasseSecret
 */
import { execSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const outPath = join(root, 'server-root', '.htpasswd');

const [user, ...passwordParts] = process.argv.slice(2);
const password = passwordParts.join(' ');

if (!user || !password) {
  console.error('\nUsage : npm run gen:htpasswd -- <utilisateur> <mot-de-passe>\n');
  console.error('Exemple : npm run gen:htpasswd -- equipe Kelegance2026!\n');
  process.exit(1);
}

let hash;
try {
  hash = execSync(`openssl passwd -apr1 "${password.replace(/"/g, '\\"')}"`, {
    encoding: 'utf8',
  }).trim();
} catch {
  console.error('\n✗ openssl introuvable. Installez OpenSSL ou créez .htpasswd manuellement :');
  console.error('  htpasswd -c server-root/.htpasswd equipe\n');
  process.exit(1);
}

const ligne = `${user}:${hash}\n`;
writeFileSync(outPath, ligne, { mode: 0o600 });
console.log(`\n✓ ${outPath} créé pour l'utilisateur « ${user} »`);
console.log('  Uploadez ce fichier à la racine de votre serveur (à côté de .htaccess).\n');
