# Kelegance — Checklist Deep Links & PWA (production)

**Domaine :** `https://cheerful-salamander-565dfc.netlify.app`  
**Date du test :** _______________  
**Testeur :** _______________  
**Appareil :** _______________ (iOS / Android, modèle)

---

## URLs à tester

| Rôle | URL |
|------|-----|
| Accueil | https://cheerful-salamander-565dfc.netlify.app/ |
| Client (QR) | https://cheerful-salamander-565dfc.netlify.app/reserver |
| Bras Droit (QR) | https://cheerful-salamander-565dfc.netlify.app/gestion |
| Admin QR | https://cheerful-salamander-565dfc.netlify.app/admin/qrcodes |

---

## A. Navigateur mobile — Deep links

### `/reserver` (Client)

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| A1 | Ouvrir https://cheerful-salamander-565dfc.netlify.app/reserver — la page Kelegance charge | ☐ | ☐ | |
| A2 | L’URL reste `/reserver` (pas de `#/` dans la barre) | ☐ | ☐ | |
| A3 | Bandeau « réservation » visible si non connecté | ☐ | ☐ | |
| A4 | Connexion **client** → onglet réservation s’ouvre | ☐ | ☐ | |
| A5 | Recharger la page → même comportement | ☐ | ☐ | |
| A6 | Scanner le **QR Client** → même résultat que A1 | ☐ | ☐ | |

### `/gestion` (Bras Droit)

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| B1 | Ouvrir https://cheerful-salamander-565dfc.netlify.app/gestion — la page charge | ☐ | ☐ | |
| B2 | Message espace pro / Bras Droit si non connecté | ☐ | ☐ | |
| B3 | Écran login chauffeur s’affiche (auto ou manuel) | ☐ | ☐ | |
| B4 | Connexion **chauffeur** → console (pas espace client) | ☐ | ☐ | |
| B5 | Recharger la page → même comportement | ☐ | ☐ | |
| B6 | Scanner le **QR Bras Droit** → même résultat que B1 | ☐ | ☐ | |

---

## B. PWA — Installation écran d’accueil

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| C1 | Site ouvert **en ligne** sur `/reserver` | ☐ | ☐ | |
| C2 | **Android Chrome** : « Installer l’app » / « Ajouter à l’écran d’accueil » | ☐ | ☐ | |
| C3 | **iOS Safari** : Partager → « Sur l’écran d’accueil » | ☐ | ☐ | |
| C4 | Icône **Kelegance** visible sur l’écran d’accueil | ☐ | ☐ | |
| C5 | Ouverture via l’icône → mode plein écran (sans barre navigateur) | ☐ | ☐ | |

---

## C. Deep links depuis l’icône PWA

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| D1 | Ouvrir l’icône PWA → app Kelegance démarre | ☐ | ☐ | |
| D2 | Scanner QR **Client** → parcours `/reserver` OK | ☐ | ☐ | |
| D3 | Scanner QR **Bras Droit** → parcours `/gestion` OK | ☐ | ☐ | |
| D4 | Lien `/reserver` collé dans SMS/Notes → ouvre bien l’app | ☐ | ☐ | |

---

## D. Cache hors ligne (après 1 visite en ligne)

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| E1 | Visite en ligne réussie **au moins une fois** sur cet appareil | ☐ | ☐ | |
| E2 | Mode avion activé | ☐ | ☐ | |
| E3 | Ouvrir icône PWA ou `/reserver` → **interface** visible | ☐ | ☐ | |
| E4 | Connexion / réservation hors ligne → échec attendu (Firebase) | ☐ | ☐ | |
| E5 | Réseau réactivé → connexion et réservation OK | ☐ | ☐ | |

---

## E. Cas limites

| # | Test | OK | KO | Notes |
|---|------|:--:|:--:|-------|
| F1 | Client connecté + `/gestion` → reste espace **client** | ☐ | ☐ | |
| F2 | Chauffeur connecté + `/gestion` → **console** directe | ☐ | ☐ | |
| F3 | `/admin/qrcodes` sans admin → message accès refusé | ☐ | ☐ | |
| F4 | Première visite jamais faite + hors ligne → échec normal | ☐ | ☐ | |

---

## Validation finale (6 points bloquants)

- [ ] **1.** `/reserver` OK navigateur mobile  
- [ ] **2.** `/gestion` OK navigateur mobile  
- [ ] **3.** QR Client → `/reserver`  
- [ ] **4.** QR Bras Droit → `/gestion`  
- [ ] **5.** PWA installable et ouvrable  
- [ ] **6.** Interface en cache après 1ère visite en ligne  

**Résultat global :** ☐ GO production  ☐ À corriger  

**Commentaires :**  
_____________________________________________________________________________  
_____________________________________________________________________________  

---

*Script automatique (ordinateur) : `npm run test:deeplinks`*
