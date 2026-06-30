/**
 * Overlay de discrétion — masque l'écran dès que l'app passe en arrière-plan.
 * Web · PWA iPhone · hub client.
 */
export function initOverlayDiscretion() {
  var el = document.getElementById('kelegance-overlay-discretion');
  if (!el) return;

  function afficher() {
    el.classList.add('visible');
    el.setAttribute('aria-hidden', 'false');
  }

  function masquer() {
    el.classList.remove('visible');
    el.setAttribute('aria-hidden', 'true');
  }

  function synchroniser() {
    if (document.hidden || document.visibilityState === 'hidden') {
      afficher();
    } else {
      masquer();
    }
  }

  document.addEventListener('visibilitychange', synchroniser);
  window.addEventListener('pagehide', afficher);
  window.addEventListener('pageshow', masquer);

  if (document.hidden) afficher();
}
