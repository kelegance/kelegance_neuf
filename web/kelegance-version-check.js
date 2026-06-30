/**
 * Vérification de version PWA — compare /version.json au build local et force
 * purge cache + rechargement si une nouvelle version est déployée.
 *
 * Forçage manuel (iPhone / cache bloqué) :
 *   ?v=1.0.15  ou  ?refresh=1  ou  ?force_update=1
 */
(function (global) {
  var STORAGE_KEY = 'kelegance_web_build_id';
  var VERSION_URL = '/version.json';

  function empreinteBuild(payload) {
    if (!payload) return null;
    var buildId = payload.buildId || '';
    var version = payload.version || '';
    var buildNumber = payload.buildNumber != null ? String(payload.buildNumber) : '';
    if (buildId) return buildId;
    if (version && buildNumber) return version + '-b' + buildNumber;
    return version || null;
  }

  function doitForcerRafraichissement() {
    try {
      var params = new URLSearchParams(global.location.search);
      return params.has('v') || params.has('refresh') || params.get('force_update') === '1';
    } catch (e) {
      return false;
    }
  }

  function urlSansParametresForce() {
    var u = new URL(global.location.href);
    u.searchParams.delete('v');
    u.searchParams.delete('refresh');
    u.searchParams.delete('force_update');
    u.searchParams.delete('t');
    return u.toString();
  }

  function purgeCachesAndServiceWorkers() {
    var tasks = [];
    if (global.caches) {
      tasks.push(
        caches.keys().then(function (keys) {
          return Promise.all(keys.map(function (key) { return caches.delete(key); }));
        }),
      );
    }
    if ('serviceWorker' in global.navigator) {
      tasks.push(
        navigator.serviceWorker.getRegistrations().then(function (regs) {
          return Promise.all(regs.map(function (reg) { return reg.unregister(); }));
        }),
      );
    }
    return Promise.all(tasks);
  }

  global.keleganceVerifierVersion = function (onReady) {
    var done = typeof onReady === 'function' ? onReady : function () {};

    if (doitForcerRafraichissement()) {
      try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
      return purgeCachesAndServiceWorkers().then(function () {
        global.location.replace(urlSansParametresForce());
      });
    }

    var url = VERSION_URL + '?t=' + Date.now();

    fetch(url, { cache: 'no-store', credentials: 'same-origin' })
      .then(function (response) {
        if (!response.ok) throw new Error('version-unavailable');
        return response.json();
      })
      .then(function (payload) {
        var next = empreinteBuild(payload);
        if (!next) {
          done();
          return;
        }

        var prev = null;
        try { prev = localStorage.getItem(STORAGE_KEY); } catch (e) {}

        if (prev && prev !== next) {
          try { localStorage.setItem(STORAGE_KEY, next); } catch (e) {}
          return purgeCachesAndServiceWorkers().then(function () {
            global.location.reload();
          });
        }

        try { localStorage.setItem(STORAGE_KEY, next); } catch (e) {}
        done();
      })
      .catch(function () { done(); });
  };
})(window);
