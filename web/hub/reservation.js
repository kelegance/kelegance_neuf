import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getFirestore,
  collection,
  addDoc,
  serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyAnoBWmYeMAUF1X6Rg2NRTgWzdVSLowaro',
  authDomain: 'kelegance.firebaseapp.com',
  projectId: 'kelegance',
  storageBucket: 'kelegance.firebasestorage.app',
  messagingSenderId: '766009026310',
  appId: '1:766009026310:web:e7e3e6c8fa24cd2d8a6087',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

function debounce(fn, ms) {
  let t;
  return function (...args) {
    clearTimeout(t);
    t = setTimeout(() => fn.apply(this, args), ms);
  };
}

function formaterDateIso(dateStr) {
  return dateStr;
}

function formaterHeure(heureStr) {
  const parts = heureStr.split(':');
  const h = parts[0].padStart(2, '0');
  const m = (parts[1] || '00').padStart(2, '0');
  return h + ':' + m;
}

function estEmail(valeur) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(valeur);
}

function estTelephone(valeur) {
  const chiffres = valeur.replace(/\D/g, '');
  return chiffres.length >= 9 && chiffres.length <= 15;
}

function normaliserContact(valeur) {
  const brut = valeur.trim();
  if (estEmail(brut)) {
    return { brut, email: brut.toLowerCase(), phone: null };
  }
  if (estTelephone(brut)) {
    return { brut, email: null, phone: brut };
  }
  return null;
}

function creerAutocomplete(inputEl, listeEl) {
  let indexActif = -1;

  const masquer = () => {
    listeEl.classList.remove('visible');
    listeEl.innerHTML = '';
    indexActif = -1;
  };

  const choisir = (texte) => {
    inputEl.value = texte;
    masquer();
  };

  const afficher = (suggestions) => {
    listeEl.innerHTML = '';
    if (!suggestions.length) {
      masquer();
      return;
    }
    suggestions.forEach((s, i) => {
      const li = document.createElement('li');
      li.textContent = s;
      li.setAttribute('role', 'option');
      li.addEventListener('mousedown', (e) => {
        e.preventDefault();
        choisir(s);
      });
      listeEl.appendChild(li);
    });
    listeEl.classList.add('visible');
  };

  const rechercher = debounce(async () => {
    const q = inputEl.value.trim();
    if (q.length < 3) {
      masquer();
      return;
    }
    if (typeof window.kelegancePlacesAutocomplete !== 'function') {
      masquer();
      return;
    }
    try {
      const raw = await window.kelegancePlacesAutocomplete(q);
      const suggestions = (raw || []).map((p) => p.description || p).filter(Boolean).slice(0, 6);
      afficher(suggestions);
    } catch (_) {
      masquer();
    }
  }, 280);

  inputEl.addEventListener('input', rechercher);
  inputEl.addEventListener('blur', () => setTimeout(masquer, 180));
  inputEl.addEventListener('keydown', (e) => {
    const items = listeEl.querySelectorAll('li');
    if (!items.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      indexActif = Math.min(indexActif + 1, items.length - 1);
      items.forEach((el, i) => el.classList.toggle('actif', i === indexActif));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      indexActif = Math.max(indexActif - 1, 0);
      items.forEach((el, i) => el.classList.toggle('actif', i === indexActif));
    } else if (e.key === 'Enter' && indexActif >= 0) {
      e.preventDefault();
      choisir(items[indexActif].textContent);
    } else if (e.key === 'Escape') {
      masquer();
    }
  });
}

export function initReservationHub() {
  const form = document.getElementById('form-reservation');
  const zoneSucces = document.getElementById('reservation-succes');
  const zoneForm = document.getElementById('zone-formulaire');
  const btnSubmit = document.getElementById('btn-envoyer-reservation');
  const erreurEl = document.getElementById('reservation-erreur');

  if (!form) return;

  const inputDate = document.getElementById('champ-date');
  const inputHeure = document.getElementById('champ-heure');
  const inputDepart = document.getElementById('champ-depart');
  const inputDestination = document.getElementById('champ-destination');
  const inputContact = document.getElementById('champ-contact');
  const inputPassagers = document.getElementById('champ-passagers');
  const listeDepart = document.getElementById('suggestions-depart');
  const listeDestination = document.getElementById('suggestions-destination');

  const aujourdhui = new Date();
  const minDate = aujourdhui.toISOString().slice(0, 10);
  inputDate.min = minDate;
  inputDate.value = minDate;

  const maintenant = new Date();
  maintenant.setMinutes(maintenant.getMinutes() + 30 - (maintenant.getMinutes() % 15));
  inputHeure.value =
    String(maintenant.getHours()).padStart(2, '0') +
    ':' +
    String(maintenant.getMinutes()).padStart(2, '0');

  creerAutocomplete(inputDepart, listeDepart);
  creerAutocomplete(inputDestination, listeDestination);

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    erreurEl.classList.add('masque');
    erreurEl.textContent = '';

    const depart = inputDepart.value.trim();
    const destination = inputDestination.value.trim();
    const date = formaterDateIso(inputDate.value);
    const heure = formaterHeure(inputHeure.value);
    const passagers = Math.max(1, Math.min(8, parseInt(inputPassagers.value, 10) || 1));
    const contact = normaliserContact(inputContact.value);

    if (!depart || !destination || !date || !heure || !inputContact.value.trim()) {
      erreurEl.textContent = 'Veuillez remplir tous les champs.';
      erreurEl.classList.remove('masque');
      return;
    }

    if (!contact) {
      erreurEl.textContent = 'Indiquez un numéro de téléphone ou une adresse e-mail valide.';
      erreurEl.classList.remove('masque');
      return;
    }

    btnSubmit.disabled = true;
    btnSubmit.classList.add('envoi');

    try {
      const mission = {
        client: contact.email || 'Carte QR',
        contactHub: contact.brut,
        depart,
        destination: destination.toUpperCase(),
        date,
        heure,
        passagers,
        statut: 'EN ATTENTE',
        source: 'hub_qr',
        type: 'RÉSERVATION HUB',
        prix: 0,
        libelleTarif: 'À confirmer',
        createdAt: serverTimestamp(),
      };
      if (contact.email) mission.email = contact.email;
      if (contact.phone) mission.phone = contact.phone;

      const ref = await addDoc(collection(db, 'missions'), mission);

      document.getElementById('succes-ref').textContent = ref.id.slice(-6).toUpperCase();
      zoneForm.classList.add('masque');
      zoneSucces.classList.remove('masque');
      form.reset();
      inputDate.value = minDate;
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } catch (err) {
      console.error('Réservation hub:', err);
      erreurEl.textContent =
        'Impossible d\'enregistrer la demande. Vérifiez votre connexion et réessayez.';
      erreurEl.classList.remove('masque');
      btnSubmit.disabled = false;
      btnSubmit.classList.remove('envoi');
    }
  });

  document.getElementById('btn-nouvelle-reservation')?.addEventListener('click', () => {
    zoneSucces.classList.add('masque');
    zoneForm.classList.remove('masque');
    btnSubmit.disabled = false;
    btnSubmit.classList.remove('envoi');
    erreurEl.classList.add('masque');
  });
}
