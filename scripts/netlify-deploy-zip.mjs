#!/usr/bin/env node
/**
 * Déploie build/web sur Netlify via l'API REST (zip) — sans netlify-cli.
 * Requiert NETLIFY_AUTH_TOKEN (Personal access token Netlify).
 */
import { createWriteStream, existsSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = process.cwd();
const buildDir = join(root, 'build', 'web');
const zipPath = join(root, '.netlify-deploy.zip');
const token = process.env.NETLIFY_AUTH_TOKEN;
const siteSlug = process.env.NETLIFY_SITE_ID || 'cheerful-salamander-565dfc';
const webOrigin =
  process.env.KELEGANCE_WEB_ORIGIN || 'https://cheerful-salamander-565dfc.netlify.app';

if (!token) {
  console.error('✗ NETLIFY_AUTH_TOKEN manquant.');
  console.error('  Créez un token : https://app.netlify.com/user/applications#personal-access-tokens');
  console.error('  Puis : $env:NETLIFY_AUTH_TOKEN="..." ; node scripts/netlify-deploy-zip.mjs');
  process.exit(1);
}

if (!existsSync(buildDir)) {
  console.error('✗ build/web introuvable — lancez d’abord le build Flutter.');
  process.exit(1);
}

function creerZip() {
  if (existsSync(zipPath)) rmSync(zipPath);

  if (process.platform === 'win32') {
    const ps = `Compress-Archive -Path '${buildDir.replace(/'/g, "''")}\\*' -DestinationPath '${zipPath.replace(/'/g, "''")}' -Force`;
    const result = spawnSync('powershell', ['-NoProfile', '-Command', ps], { stdio: 'inherit' });
    if (result.status !== 0) throw new Error('Échec Compress-Archive');
    return;
  }

  const result = spawnSync('zip', ['-r', '-q', zipPath, '.'], { cwd: buildDir, stdio: 'inherit' });
  if (result.status !== 0) throw new Error('Échec zip');
}

async function deployer() {
  creerZip();
  const zip = readFileSync(zipPath);

  const siteRes = await fetch(`https://api.netlify.com/api/v1/sites/${siteSlug}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!siteRes.ok) {
    throw new Error(`Site Netlify introuvable (${siteRes.status})`);
  }
  const site = await siteRes.json();

  const deployRes = await fetch(`https://api.netlify.com/api/v1/sites/${site.id}/deploys`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/zip',
    },
    body: zip,
  });

  if (!deployRes.ok) {
    const detail = await deployRes.text();
    throw new Error(`Échec upload Netlify (${deployRes.status}) : ${detail.slice(0, 300)}`);
  }

  const deploy = await deployRes.json();
  const url = deploy.ssl_url || deploy.url || webOrigin;
  console.log('\n✓ Déploiement Netlify terminé.');
  console.log(`  URL         : ${url}`);
  console.log(`  Deploy ID   : ${deploy.id}`);
  console.log(`  État        : ${deploy.state}`);
  rmSync(zipPath, { force: true });
}

deployer().catch((err) => {
  console.error(`\n✗ ${err.message}`);
  process.exit(1);
});
