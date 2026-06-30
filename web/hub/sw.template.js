'use strict';

/** Service worker Hub — cache versionné, invalidé à chaque déploiement. */
const BUILD_ID = '%%BUILD_ID%%';
const CACHE = 'kelegance-hub-' + BUILD_ID;

const NETWORK_FIRST = [
  '/version.json',
  '/hub/',
  '/hub/index.html',
  '/hub/reservation.js',
  '/hub/overlay-discretion.js',
  '/hub/manifest.webmanifest',
  '/hub/sw.js',
];

function estNetworkFirst(url) {
  var path = url.pathname;
  return NETWORK_FIRST.indexOf(path) !== -1 || url.searchParams.has('t') || url.searchParams.has('v') || url.searchParams.has('refresh');
}

function purgeHubCaches() {
  return caches.keys().then(function (keys) {
    return Promise.all(
      keys
        .filter(function (key) { return key !== CACHE; })
        .map(function (key) { return caches.delete(key); }),
    );
  });
}

self.addEventListener('install', function (event) {
  event.waitUntil(purgeHubCaches().then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (event) {
  event.waitUntil(purgeHubCaches().then(function () { return self.clients.claim(); }));
});

self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;

  var url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (estNetworkFirst(url) || event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then(function (response) {
          if (response.ok) {
            var clone = response.clone();
            caches.open(CACHE).then(function (cache) {
              cache.put(event.request, clone);
            });
          }
          return response;
        })
        .catch(function () { return caches.match(event.request); }),
    );
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(function (response) {
        if (response.ok) {
          var clone = response.clone();
          caches.open(CACHE).then(function (cache) {
            cache.put(event.request, clone);
          });
        }
        return response;
      })
      .catch(function () { return caches.match(event.request); }),
  );
});
