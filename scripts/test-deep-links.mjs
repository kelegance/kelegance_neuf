#!/usr/bin/env node
/**
 * Vérifie en production que les routes deep link et la PWA répondent correctement.
 *
 * Usage :
 *   node scripts/test-deep-links.mjs
 *   node scripts/test-deep-links.mjs --origin https://votre-site.netlify.app
 *   node scripts/test-deep-links.mjs --origin https://cheerful-salamander-565dfc.netlify.app --verbose
 */
const ORIGIN_DEFAUT = 'https://cheerful-salamander-565dfc.netlify.app';

const ROUTES = [
  { id: 'accueil', path: '/', label: 'Accueil', attendHtml: true },
  { id: 'reserver', path: '/reserver', label: 'Deep link Client', attendHtml: true },
  { id: 'gestion', path: '/gestion', label: 'Deep link Bras Droit', attendHtml: true },
  { id: 'admin-qr', path: '/admin/qrcodes', label: 'Admin QR codes', attendHtml: true },
  { id: 'manifest', path: '/manifest.json', label: 'Manifest PWA', attendJson: true },
  { id: 'sw', path: '/flutter_service_worker.js', label: 'Service worker (absent)', attendAbsent: true },
  { id: 'bootstrap', path: '/flutter_bootstrap.js', label: 'Flutter bootstrap', attendJs: true },
  { id: 'main', path: '/main.dart.js', label: 'Application Flutter', attendJs: true },
];

function parseArgs() {
  const args = process.argv.slice(2);
  let origin = process.env.KELEGANCE_WEB_ORIGIN || ORIGIN_DEFAUT;
  let verbose = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--origin' && args[i + 1]) {
      origin = args[++i].replace(/\/$/, '');
    } else if (args[i] === '--verbose' || args[i] === '-v') {
      verbose = true;
    } else if (args[i] === '--help' || args[i] === '-h') {
      console.log(`Usage: node scripts/test-deep-links.mjs [--origin URL] [--verbose]

Vérifie les deep links et fichiers PWA sur l'hébergement de production.

  --origin   URL de base (défaut: ${ORIGIN_DEFAUT})
  --verbose  Affiche les détails de chaque réponse
`);
      process.exit(0);
    }
  }

  return { origin, verbose };
}

async function testerUrl(url, options = {}) {
  const debut = Date.now();
  try {
    const response = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      headers: { Accept: 'text/html,application/json,*/*' },
    });
    const duree = Date.now() - debut;
    const contentType = response.headers.get('content-type') || '';
    const body = options.lireCorps ? await response.text() : '';

    return {
      ok: response.ok,
      status: response.status,
      contentType,
      body,
      duree,
      urlFinale: response.url,
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      erreur: error.message,
      duree: Date.now() - debut,
      urlFinale: url,
    };
  }
}

function contientFlutterShell(html) {
  return (
    html.includes('flutter_bootstrap.js') ||
    html.includes('kelegance-loader') ||
    html.includes('KELEGANCE')
  );
}

function contientServiceWorkerConfig(js) {
  return /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:/.test(js);
}

function evaluerRoute(route, result) {
  const problemes = [];

  if (!result.ok) {
    if (route.attendAbsent && result.status === 404) {
      return problemes;
    }
    problemes.push(result.erreur ? `Réseau : ${result.erreur}` : `HTTP ${result.status}`);
    return problemes;
  }

  if (route.attendHtml) {
    if (!result.contentType.includes('text/html')) {
      problemes.push(`Content-Type inattendu : ${result.contentType}`);
    }
    if (!contientFlutterShell(result.body)) {
      problemes.push('Réponse HTML sans shell Flutter (redirect SPA cassé ?)');
    }
  }

  if (route.attendJson && !result.contentType.includes('json')) {
    problemes.push(`Manifest non JSON : ${result.contentType}`);
  }

  if (route.attendAbsent && result.ok) {
    problemes.push('flutter_service_worker.js ne devrait pas être déployé');
  }

  if (route.attendJs && route.id === 'bootstrap' && contientServiceWorkerConfig(result.body)) {
    problemes.push('flutter_bootstrap.js enregistre encore un service worker');
  }

  return problemes;
}

function afficherLigne(ok, label, detail) {
  const icone = ok ? '✓' : '✗';
  console.log(`  ${icone} ${label}${detail ? ` — ${detail}` : ''}`);
}

async function main() {
  const { origin, verbose } = parseArgs();

  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║  Kelegance — Test deep links & PWA (production)          ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log(`\nOrigine : ${origin}\n`);

  const resultats = [];
  let echecs = 0;

  for (const route of ROUTES) {
    const url = `${origin}${route.path}`;
    const result = await testerUrl(url, { lireCorps: true });
    const problemes = evaluerRoute(route, result);
    const succes = problemes.length === 0;

    if (!succes) echecs++;

    resultats.push({ route, url, result, problemes, succes });

    const detail = `${result.status || '—'} · ${result.duree}ms`;
    afficherLigne(succes, `${route.label} (${route.path})`, detail);

    if (!succes) {
      for (const p of problemes) {
        console.log(`      → ${p}`);
      }
    }

    if (verbose && result.body) {
      const extrait = result.body.slice(0, 120).replace(/\s+/g, ' ');
      console.log(`      … ${extrait}`);
    }
  }

  console.log('\n── URLs à tester sur mobile ──────────────────────────────');
  console.log(`  Client      : ${origin}/reserver`);
  console.log(`  Bras Droit  : ${origin}/gestion`);
  console.log(`  Admin QR    : ${origin}/admin/qrcodes`);
  console.log('\n── Checklist imprimable ──────────────────────────────────');
  console.log('  docs/checklist-deep-links-pwa.md\n');

  if (echecs === 0) {
    console.log('✓ Tous les tests serveur sont OK. Passez à la checklist mobile.\n');
    process.exit(0);
  }

  console.log(`✗ ${echecs} test(s) en échec. Corrigez avant la validation mobile.\n`);
  process.exit(1);
}

main();
