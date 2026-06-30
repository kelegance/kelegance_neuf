#!/usr/bin/env node
/**
 * Diagnostic accès Bras Droit — vérifie la configuration attendue dans Firestore.
 *
 * Usage :
 *   node scripts/debug-acces-roles.mjs deborah.jetil@gmail.com
 *
 * Ce script ne se connecte pas à Firebase : il affiche la checklist et les
 * e-mails de la liste officielle embarquée dans l'app.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const emailArg = process.argv[2]?.toLowerCase().trim();

const rolesDart = readFileSync(join(process.cwd(), 'lib', 'kelegance_init_firestore.dart'), 'utf8');
const emailsOfficiels = [
  ...rolesDart.matchAll(/emailAdmin\w*\s*=\s*'([^']+)'/g),
].map((m) => m[1].toLowerCase());

console.log('=== KELEGANCE — Diagnostic accès Bras Droit ===\n');
console.log('E-mails liste officielle (app) :');
for (const e of emailsOfficiels) console.log(`  • ${e}`);

if (!emailArg) {
  console.log('\nUsage : node scripts/debug-acces-roles.mjs <email>');
  console.log('\nDans Firebase Console → Firestore, vérifier pour cet e-mail :');
  console.log('  1. Collection users — document UID ou where email == …');
  console.log('  2. Collection chauffeurs — document UID');
  console.log('\nChamps qui accordent Bras Droit :');
  console.log('  role: "admin" | "bras_droit"');
  console.log('  niveauAcces: "bras_droit" | "admin"');
  console.log('  accesBrasDroit: true');
  console.log('  accesAdmin / isAdmin: true');
  console.log('\nDans l\'app : Paramètres → Diagnostic accès (après connexion chauffeur).');
  process.exit(0);
}

const listeOk = emailsOfficiels.includes(emailArg);
console.log(`\nE-mail testé : ${emailArg}`);
console.log(`Liste officielle : ${listeOk ? 'OUI ✓' : 'NON — ajouter role/niveauAcces dans Firestore'}`);

if (!listeOk) {
  console.log('\nPour accorder Bras Droit via Firestore, fusionner sur users/{uid} et chauffeurs/{uid} :');
  console.log(JSON.stringify({ role: 'chauffeur', niveauAcces: 'bras_droit', accesBrasDroit: true }, null, 2));
}

console.log('\nAprès modification Firestore : déconnexion/reconnexion ou Paramètres → Rafraîchir le diagnostic.');
