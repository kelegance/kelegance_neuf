#!/usr/bin/env node
/**
 * Exporte les cartes de visite KELEGANCE en PDF séparés Recto / Verso.
 *
 * Usage :
 *   npm run export:cartes-visite
 *   node scripts/export-cartes-visite-pdf.mjs [nicolas|deborah|linel]
 *
 * Prérequis : puppeteer (devDependency)
 * Sortie :
 *   web/print/pdf/carte-<id>-recto.pdf
 *   web/print/pdf/carte-<id>-verso.pdf
 *   web/print/pdf/carte-verso-commun.pdf (verso partagé, 1 page)
 */
import { createRequire } from 'node:module';
import { mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const htmlPath = join(root, 'web', 'print', 'carte-visite-kelegance.html');
const outDir = join(root, 'web', 'print', 'pdf');

const PERSONNES = ['nicolas', 'deborah', 'linel'];
const FACES = ['recto', 'verso'];
const cible = process.argv[2]?.toLowerCase();
const liste = cible && PERSONNES.includes(cible) ? [cible] : PERSONNES;

const PDF_OPTS = {
  width: '91mm',
  height: '61mm',
  printBackground: true,
  margin: { top: 0, right: 0, bottom: 0, left: 0 },
  preferCSSPageSize: true,
};

if (!existsSync(htmlPath)) {
  console.error('Fichier introuvable :', htmlPath);
  process.exit(1);
}

let puppeteer;
try {
  puppeteer = require('puppeteer');
} catch {
  console.error('Puppeteer requis. Exécutez : npm install puppeteer --save-dev');
  process.exit(1);
}

mkdirSync(outDir, { recursive: true });

const fileUrl = (id, face) =>
  `file:///${htmlPath.replace(/\\/g, '/')}?export=${id}&face=${face}`;

async function exporterFace(browser, id, face) {
  const page = await browser.newPage();
  await page.goto(fileUrl(id, face), { waitUntil: 'networkidle0', timeout: 60000 });
  const selector = face === 'recto' ? '.page.recto img' : '.page.verso img';
  await page.waitForSelector(selector, { timeout: 30000 });
  await new Promise((r) => setTimeout(r, 800));

  const outFile = join(outDir, `carte-${id}-${face}.pdf`);
  await page.pdf({ path: outFile, ...PDF_OPTS });
  await page.close();
  console.log(`✓ ${outFile}`);
  return outFile;
}

console.log('KELEGANCE — Export PDF cartes de visite (Recto / Verso séparés)');
console.log('  Format : 91 × 61 mm (fond perdu 3 mm) · rognage 85 × 55 mm · zone sûre 3 mm\n');

const browser = await puppeteer.launch({
  headless: true,
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});

try {
  for (const id of liste) {
    for (const face of FACES) {
      await exporterFace(browser, id, face);
    }
  }

  const versoCommun = join(outDir, 'carte-verso-commun.pdf');
  const page = await browser.newPage();
  await page.goto(fileUrl('nicolas', 'verso'), { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('.page.verso img', { timeout: 30000 });
  await new Promise((r) => setTimeout(r, 800));
  await page.pdf({ path: versoCommun, ...PDF_OPTS });
  await page.close();
  console.log(`✓ ${versoCommun} (verso identique pour toutes les cartes)`);
} finally {
  await browser.close();
}

console.log('\nPrêt pour Canva / VistaPrint : téléversez le PDF Recto et le PDF Verso séparément.');
