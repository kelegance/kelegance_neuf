'use strict';

/**
 * Service worker Kelegance — cache shell PWA + routes SPA.
 * Généré par scripts/prepare-web-build.mjs après `flutter build web`.
 * CACHE_NAME change à chaque build → purge des anciens caches à l'install et à l'activate.
 */
const CACHE_NAME = '%%CACHE_NAME%%';
const BUILD_ID = '%%BUILD_ID%%';
const PRECACHE_URLS = %%PRECACHE_URLS%%;

const NAVIGATION_FALLBACK = '/app.html';

const NETWORK_FIRST_PATHS = [
  '/app.html',
  '/index.html',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/version.json',
  '/kelegance-version-check.js',
  '/flutter_service_worker.js',
  '/kelegance-service-worker.js',
  '/releases/web-latest.json',
];

function purgeAnciensCaches() {
  return caches.keys().then((keys) =>
    Promise.all(
      keys
        .filter((key) => key !== CACHE_NAME)
        .map((key) => caches.delete(key)),
    ),
  );
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    purgeAnciensCaches()
      .then(() => caches.open(CACHE_NAME))
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
      .catch((error) => {
        console.warn('[Kelegance SW]', BUILD_ID, 'precache partiel:', error);
        return self.skipWaiting();
      }),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    purgeAnciensCaches().then(() => self.clients.claim()),
  );
});

function estRequeteNavigation(request) {
  return request.mode === 'navigate' || request.headers.get('accept')?.includes('text/html');
}

function estNetworkFirst(url) {
  const path = url.pathname;
  if (NETWORK_FIRST_PATHS.includes(path)) return true;
  if (path.endsWith('.js') && !path.includes('canvaskit')) return true;
  if (url.searchParams.has('t')) return true;
  if (url.searchParams.has('v')) return true;
  if (url.searchParams.has('refresh')) return true;
  if (url.searchParams.get('force_update') === '1') return true;
  return false;
}

function estAssetStatique(url) {
  if (url.origin !== self.location.origin) return false;
  const path = url.pathname;
  return (
    path.endsWith('.js') ||
    path.endsWith('.wasm') ||
    path.endsWith('.json') ||
    path.endsWith('.png') ||
    path.endsWith('.jpg') ||
    path.endsWith('.otf') ||
    path.endsWith('.ttf') ||
    path.endsWith('.bin') ||
    path.startsWith('/assets/') ||
    path.startsWith('/canvaskit/') ||
    path.startsWith('/icons/')
  );
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (estRequeteNavigation(request) || estNetworkFirst(url)) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              if (estRequeteNavigation(request)) {
                cache.put(NAVIGATION_FALLBACK, clone);
              } else {
                cache.put(request, clone);
              }
            });
          }
          return response;
        })
        .catch(() => {
          if (estRequeteNavigation(request)) {
            return caches.match(NAVIGATION_FALLBACK);
          }
          return caches.match(request);
        }),
    );
    return;
  }

  if (!estAssetStatique(url)) return;

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      })
      .catch(() => caches.match(request)),
  );
});
