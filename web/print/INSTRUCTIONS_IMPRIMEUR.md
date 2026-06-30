# KELEGANCE — Brief imprimeur cartes de visite Luxe

## Fichiers à transmettre

| Fichier | Usage |
|---------|--------|
| `web/print/pdf/carte-nicolas.pdf` | PDF 2 pages — **p.1 Recto** · **p.2 Verso** |
| `web/print/pdf/carte-deborah.pdf` | Idem — Déborah Jetil |
| `web/print/pdf/carte-linel.pdf` | Idem — Marc Alexandre Linel |
| `carte-visite-kelegance.html` | Prévisualisation écran + export manuel Chrome |

### Générer les PDF

```bash
npm install
npm run export:cartes-visite
```

Export d'une seule carte : `node scripts/export-cartes-visite-pdf.mjs deborah`

**URL encodée dans le QR Code (verso)** — Hub Client :  
`https://cheerful-salamander-565dfc.netlify.app/hub`

---

## Format & finitions

| Paramètre | Valeur |
|-----------|--------|
| Format rognage | **85 × 55 mm** (standard européen) |
| Fond perdu (bleed) | **3 mm** par côté → fichier **91 × 61 mm** |
| Zone de sécurité | **3 mm** à l'intérieur du rognage (texte & QR) |
| Résolution | **300 DPI** minimum (QR généré 600×600 px) |
| Fond | **Noir profond** `#0A0A0A` (recto plein) |
| Dorure / Or | **#D4AF37** (texte KELEGANCE, titres, mention verso) |
| Texte principal | **#F5F0E6** (blanc cassé) |
| Papier recommandé | **350 g/m² minimum** — couché mat ou demi-mat |
| Coins | Option **coins arrondis 3 mm** (premium, non obligatoire) |

### Import plateformes en ligne (Vistaprint, Moo, etc.)

- Téléverser le PDF **tel quel** : **page 1 = Recto**, **page 2 = Verso**
- Choisir format **85 × 55 mm** avec fond perdu si proposé
- Vérifier que l'option « fond perdu » correspond au fichier 91×61 mm

---

## Finitions luxe à commander

### 1. Soft Touch (pelliculage mat velours)

- Demander : **« Pelliculage Soft Touch recto-verso »** ou **« Lamination soft touch matte »**
- Effet : toucher velours, aspect premium, réduit les reflets
- Idéal sur fond noir — valorise le contraste or / noir

### 2. Vernis sélectif (UV spot)

- Demander : **« Vernis UV sélectif »** sur les éléments suivants **uniquement** :
  - Logo KELEGANCE (cercle + lettres)
  - Texte « KELEGANCE » (recto)
  - Mention « Spécialistes Transferts Aéroports & Gares » (verso)
  - Cadre fin autour du QR (optionnel)
- **Ne pas vernir** : le fond noir (garder le mat Soft Touch) ni le QR code (lisibilité scan)
- Effet : relief brillant discret sur l'or — signature « luxe »

### 3. Ordre des passes (à préciser à l'imprimeur)

1. Impression offset ou numérique **CMJN** (fond noir dense + or en quadrichromie ou Pantone 871 C / or métallisé si budget)
2. Pelliculage **Soft Touch** intégral
3. **Vernis UV sélectif** sur les zones dorées

---

## Couleurs de référence (Pantone indicatifs)

| Élément | RVB | Pantone (indicatif) |
|---------|-----|---------------------|
| Noir fond | `#0A0A0A` | Black 6 C |
| Or KELEGANCE | `#D4AF37` | 871 C (métallisé) ou 7403 C |
| Texte clair | `#F5F0E6` | Warm Gray 1 C |

> Pour un rendu or optimal : demander **dorure à chaud** ou **foil or** sur le logo + nom KELEGANCE (surcoût, rendu haut de gamme maximal).

---

## QR Code — contraintes techniques

- Taille imprimée : **24 × 24 mm** (+ cadre blanc 1,8 mm · zone silence ≥ 2 mm)
- URL : Hub Client (`/hub`)
- Ne pas appliquer de vernis sur la surface du QR
- Tester le scan à 30 cm avant validation BAT

---

## Texte à faire figurer

**Recto** (3 versions individuelles) :

| Nom | Fonction | Contact |
|-----|----------|---------|
| Nicolas Bordelais | Direction & Opérations | nicolas.nbchauffeurs@gmail.com |
| Déborah Jetil | Direction & Opérations | 06 65 58 73 60 · deborah.jetil@gmail.com |
| Marc Alexandre Linel | Direction & Opérations | 06 72 16 69 53 · linel.marcalexandrepro@gmail.com |

**Verso** :
- QR → Hub Client (réservation & PWA)
- Mention : **Spécialistes Transferts Aéroports & Gares**

---

## Phrase type pour devis imprimeur

> « Carte de visite 85 × 55 mm, fond perdu 3 mm, 350 g couché mat, impression recto-verso fond noir + dorure, pelliculage Soft Touch intégral, vernis UV sélectif sur logo et textes dorés uniquement, QR code noir sur fond blanc non verni. BAT numérique avant tirage. »
