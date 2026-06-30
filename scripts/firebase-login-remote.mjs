#!/usr/bin/env node
/**
 * Connexion Firebase --no-localhost en deux étapes (environnement non interactif).
 *   node scripts/firebase-login-remote.mjs start
 *   node scripts/firebase-login-remote.mjs complete <CODE>
 */
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { existsSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const root = process.cwd();
const stateFile = join(root, '.firebase-login-state.json');

const auth = require('firebase-tools/lib/auth');
const apiv2 = require('firebase-tools/lib/apiv2');
const api = require('firebase-tools/lib/api');

function urlsafeBase64(base64string) {
  return base64string.replace(/\+/g, '-').replace(/=+$/, '').replace(/\//g, '_');
}

async function startLogin() {
  const authProxyClient = new apiv2.Client({
    urlPrefix: api.authProxyOrigin(),
    auth: false,
  });

  const sessionId = randomUUID();
  const codeVerifier = randomBytes(32).toString('hex');
  const codeChallenge = urlsafeBase64(createHash('sha256').update(codeVerifier).digest('base64'));
  const attestToken = (await authProxyClient.post('/attest', { session_id: sessionId })).body.token;
  const loginUrl = `${api.authProxyOrigin()}/login?code_challenge=${codeChallenge}&session=${sessionId}&attest=${attestToken}`;

  writeFileSync(
    stateFile,
    JSON.stringify({ sessionId, codeVerifier, loginUrl, createdAt: Date.now() }, null, 2),
    'utf8',
  );

  console.log('\n=== Connexion Firebase (--no-localhost) ===\n');
  console.log('1. Session ID :', sessionId.substring(0, 5).toUpperCase());
  console.log('\n2. Ouvrez ce lien dans votre navigateur :\n');
  console.log(loginUrl);
  console.log('\n3. Connectez-vous avec le compte Google du projet kelegance.');
  console.log('4. Copiez le code affiché, puis exécutez :\n');
  console.log('   node scripts/firebase-login-remote.mjs complete VOTRE_CODE\n');
}

async function completeLogin(code) {
  if (!existsSync(stateFile)) {
    console.error('Session introuvable. Relancez : node scripts/firebase-login-remote.mjs start');
    process.exit(1);
  }

  const state = JSON.parse(readFileSync(stateFile, 'utf8'));
  const trimmed = String(code ?? '').trim();
  if (!trimmed) {
    console.error('Code manquant.');
    process.exit(1);
  }

  const authProxyClient = new apiv2.Client({
    urlPrefix: api.authProxyOrigin(),
    auth: false,
  });

  const params = {
    code: trimmed,
    client_id: api.clientId(),
    client_secret: api.clientSecret(),
    redirect_uri: `${api.authProxyOrigin()}/complete`,
    grant_type: 'authorization_code',
    code_verifier: state.codeVerifier,
  };

  const FormData = require('form-data');
  const form = new FormData();
  for (const [k, v] of Object.entries(params)) form.append(k, v);

  const client = new apiv2.Client({ urlPrefix: api.authOrigin(), auth: false });
  const res = await client.request({
    method: 'POST',
    path: '/o/oauth2/token',
    body: form,
    headers: form.getHeaders(),
    skipLog: { body: true, queryParams: true, resBody: true },
  });

  if (!res.body.access_token && !res.body.refresh_token) {
    console.error('Échec échange du code. Relancez start et réessayez.');
    process.exit(1);
  }

  const jwt = require('jsonwebtoken');
  const creds = {
    user: jwt.decode(res.body.id_token, { json: true }),
    tokens: Object.assign({ expires_at: Date.now() + res.body.expires_in * 1000 }, res.body),
    scopes: [],
  };

  auth.recordCredentials(creds);
  unlinkSync(stateFile);

  console.log(`\n✓ Connecté en tant que ${creds.user.email}\n`);
}

const [,, action, code] = process.argv;

if (action === 'start') {
  await startLogin();
} else if (action === 'complete') {
  await completeLogin(code);
} else {
  console.log('Usage:');
  console.log('  node scripts/firebase-login-remote.mjs start');
  console.log('  node scripts/firebase-login-remote.mjs complete <CODE>');
  process.exit(1);
}
