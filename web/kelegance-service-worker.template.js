'use strict';

/**
 * Service worker Kelegance — cache shell PWA + routes /reserver, /gestion.
 * Généré par scripts/inject-pwa-cache.mjs après `flutter build web`.
 * Remplace le service worker Flutter (cleanup) qui ne met rien en cache.
 */
const CACHE_NAME = '%%CACHE_NAME%%';
const PRECACHE_URLS = %%PRECACHE_URLS%%;

const NAVIGATION_FALLBACK = '/index.html';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
      .catch((error) => {
        console.warn('[Kelegance SW] precache partiel:', error);
        return self.skipWaiting();
      }),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))),
      )
      .then(() => self.clients.claim()),
  );
});

function estRequeteNavigation(request) {
  return request.mode === 'navigate' || request.headers.get('accept')?.includes('text/html');
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

  // Navigation SPA (/reserver, /gestion…) — réseau puis index.html en cache.
  if (estRequeteNavigation(request)) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(NAVIGATION_FALLBACK, clone));
          }
          return response;
        })
        .catch(() => caches.match(NAVIGATION_FALLBACK)),
    );
    return;
  }

  if (!estAssetStatique(url)) return;

  // Assets Flutter — cache d'abord, mise à jour en arrière-plan si en ligne.
  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => cached);

      return cached || network;
    }),
  );
});
