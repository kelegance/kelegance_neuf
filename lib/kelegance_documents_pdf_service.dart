import 'dart:convert';

import 'kelegance_chauffeurs_referentiel.dart';

/// Données réservation extraites d'une mission Firestore — injectées dans le document web.
class KeleganceDocumentDonnees {
  const KeleganceDocumentDonnees({
    required this.type,
    required this.token,
    required this.titre,
    required this.client,
    required this.email,
    required this.depart,
    required this.destination,
    required this.date,
    required this.heure,
    required this.prixTtc,
    required this.prixHt,
    required this.tva,
    required this.netChauffeur,
    required this.fraisService,
    required this.passagers,
    required this.numeroDocument,
    required this.dateEmission,
    this.chauffeur,
    this.missionId,
    this.profilChauffeur,
  });

  final String type;
  final String token;
  final String titre;
  final String client;
  final String email;
  final String depart;
  final String destination;
  final String date;
  final String heure;
  final double prixTtc;
  final double prixHt;
  final double tva;
  final double netChauffeur;
  final double fraisService;
  final int passagers;
  final String numeroDocument;
  final String dateEmission;
  final String? chauffeur;
  final String? missionId;
  final KeleganceProfilChauffeurBdc? profilChauffeur;

  static const double tauxTvaTransport = 0.10;

  factory KeleganceDocumentDonnees.depuisMission(
    Map<String, dynamic> missionData, {
    required String type,
    required String token,
    String? numeroDocument,
    String? missionId,
    KeleganceProfilChauffeurBdc? profilChauffeur,
  }) {
    final prixTtc = (missionData['prix'] as num?)?.toDouble() ?? 0.0;
    final prixHt = double.parse((prixTtc / (1 + tauxTvaTransport)).toStringAsFixed(2));
    final tva = double.parse((prixTtc - prixHt).toStringAsFixed(2));
    final frais = double.parse((prixTtc * 0.15).toStringAsFixed(2));
    final net = double.parse((prixTtc * 0.85).toStringAsFixed(2));
    final now = DateTime.now();
    final emission =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final titre = switch (type) {
      'BON DE COMMANDE RETOUR' => 'Bon de commande retour',
      'BON DE COMMANDE VTC' => 'Bon de commande VTC',
      _ => 'Facture TTC',
    };

    final numero = numeroDocument ??
        switch (type) {
          'FACTURE TTC' => 'FAC-${now.year}-${token.substring(4, 12)}',
          _ => 'BDC-${token.substring(4, 12)}',
        };

    return KeleganceDocumentDonnees(
      type: type,
      token: token,
      titre: titre,
      client: _texte(missionData['client']),
      email: _texte(missionData['email'], fallback: _texte(missionData['client'])),
      depart: _texte(missionData['depart'], fallback: 'Non spécifié'),
      destination: _texte(missionData['destination'], fallback: 'Non spécifiée'),
      date: _texte(missionData['date'], fallback: '—'),
      heure: _texte(missionData['heure'], fallback: '—'),
      prixTtc: prixTtc,
      prixHt: prixHt,
      tva: tva,
      netChauffeur: net,
      fraisService: frais,
      passagers: (missionData['passagers'] as num?)?.toInt() ?? 1,
      numeroDocument: numero,
      dateEmission: emission,
      chauffeur: profilChauffeur?.nom ?? missionData['chauffeurAssigne']?.toString(),
      missionId: missionId,
      profilChauffeur: profilChauffeur,
    );
  }

  static String _texte(dynamic valeur, {String fallback = ''}) {
    final texte = valeur?.toString().trim() ?? '';
    return texte.isEmpty ? fallback : texte;
  }

  String get prixTtcFormate => '${prixTtc.toStringAsFixed(2)} €';
  String get prixHtFormate => '${prixHt.toStringAsFixed(2)} €';
  String get tvaFormate => '${tva.toStringAsFixed(2)} €';
}

/// Génération HTML — charte KELEGANCE (bleu nuit / or), facturation 100 % électronique.
abstract final class KeleganceDocumentsPdfService {
  static const String emailAdmin = KeleganceIdentiteDocuments.emailAdmin;
  static const String whatsappPrestige = KeleganceIdentiteDocuments.whatsappPrestige;

  static const String _couleurFond = '#0B1426';
  static const String _couleurFondClair = '#121E33';
  static const String _couleurOr = '#D4AF37';
  static const String _couleurTexte = '#F5F0E6';
  static const String _articleLegal =
      'Document de conformité réglementaire — Article L. 3122-9 du Code des transports';

  static String genererHtml({
    required String type,
    required KeleganceDocumentDonnees donnees,
  }) {
    final estBdc = type == 'BON DE COMMANDE RETOUR' || type == 'BON DE COMMANDE VTC';
    if (estBdc &&
        (donnees.profilChauffeur == null || !donnees.profilChauffeur!.estComplet)) {
      throw KeleganceChauffeurDonneesIncompletesException();
    }
    final corps = switch (type) {
      'BON DE COMMANDE RETOUR' || 'BON DE COMMANDE VTC' => _htmlBonCommande(donnees),
      _ => _htmlFacture(donnees),
    };
    return _enveloppeHtml(donnees.titre.toUpperCase(), corps);
  }

  static Map<String, String> variablesHtml(KeleganceDocumentDonnees d) => {
        '{{titre}}': _echapper(d.titre.toUpperCase()),
        '{{numeroDocument}}': _echapper(d.numeroDocument),
        '{{token}}': _echapper(d.token),
        '{{client}}': _echapper(d.client),
        '{{email}}': _echapper(d.email),
        '{{date}}': _echapper(d.date),
        '{{heure}}': _echapper(d.heure),
        '{{depart}}': _echapper(d.depart),
        '{{destination}}': _echapper(d.destination),
        '{{passagers}}': d.passagers.toString(),
        '{{prixTtc}}': _echapper(d.prixTtcFormate),
        '{{prixHt}}': _echapper(d.prixHtFormate),
        '{{tva}}': _echapper(d.tvaFormate),
        '{{tauxTva}}': '10',
        '{{prestation}}': _echapper(KeleganceIdentiteDocuments.prestationVtc),
        '{{exploitant}}': _echapper(KeleganceIdentiteDocuments.exploitant),
        '{{raisonSociale}}': _echapper(KeleganceIdentiteDocuments.raisonSociale),
        '{{siret}}': _echapper(KeleganceIdentiteDocuments.siret),
        '{{adresseSiege}}': _echapper(KeleganceIdentiteDocuments.adresseSiege),
        '{{numeroTva}}': _echapper(KeleganceIdentiteDocuments.numeroTva),
        '{{codeApe}}': _echapper(KeleganceIdentiteDocuments.codeApe),
        '{{conditionsReglement}}': _echapper(KeleganceIdentiteDocuments.conditionsReglement),
        '{{dateEmission}}': _echapper(d.dateEmission),
        '{{emailAdmin}}': _echapper(emailAdmin),
        '{{whatsapp}}': _echapper(whatsappPrestige),
        '{{whatsappLien}}': KeleganceIdentiteDocuments.lienWhatsApp,
        '{{articleLegal}}': _echapper(_articleLegal),
        '{{chauffeur}}': _echapper(d.chauffeur ?? '—'),
        '{{chauffeurNom}}': _echapper(d.profilChauffeur?.nom ?? d.chauffeur ?? '—'),
        '{{chauffeurTelephone}}': _echapper(d.profilChauffeur?.telephone ?? '—'),
        '{{chauffeurMarque}}': _echapper(d.profilChauffeur?.marque ?? '—'),
        '{{chauffeurModele}}': _echapper(d.profilChauffeur?.modele ?? '—'),
        '{{chauffeurVehicule}}': _echapper(d.profilChauffeur?.vehiculeComplet ?? '—'),
        '{{chauffeurCouleur}}': _echapper(d.profilChauffeur?.couleur ?? '—'),
        '{{chauffeurPlaque}}': _echapper(d.profilChauffeur?.plaque ?? '—'),
      };

  static String _remplacerVariables(String modele, KeleganceDocumentDonnees d) {
    var html = modele;
    for (final entree in variablesHtml(d).entries) {
      html = html.replaceAll(entree.key, entree.value);
    }
    return html;
  }

  static String _blocMentionsLegales() => '''
      <div class="mentions-legales">
        <p class="section-title" style="margin-top:0">Mentions légales &amp; facturation</p>
        <div class="grid">
          <div class="field"><label>Raison sociale</label><span>{{raisonSociale}}</span></div>
          <div class="field"><label>SIRET</label><span>{{siret}}</span></div>
          <div class="field full"><label>Siège social</label><span>{{adresseSiege}}</span></div>
          <div class="field"><label>TVA</label><span>{{numeroTva}}</span></div>
          <div class="field"><label>Code APE / NAF</label><span>{{codeApe}}</span></div>
          <div class="field full"><label>Conditions de règlement</label><span>{{conditionsReglement}}</span></div>
        </div>
      </div>''';

  static String _enveloppeHtml(String titrePage, String corps) => '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="$_couleurFond">
  <title>$titrePage — KELEGANCE PRESTIGE</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html { -webkit-text-size-adjust: 100%; }
    body {
      font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
      background: $_couleurFond;
      color: $_couleurTexte;
      line-height: 1.55;
      padding: max(16px, env(safe-area-inset-top)) 16px max(24px, env(safe-area-inset-bottom));
      min-height: 100vh;
    }
    .document {
      max-width: 760px;
      margin: 0 auto;
      background: linear-gradient(145deg, $_couleurFondClair 0%, $_couleurFond 100%);
      border: 1px solid $_couleurOr;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 8px 32px rgba(0,0,0,0.45);
    }
    .header {
      padding: 24px 24px 18px;
      border-bottom: 1px solid rgba(212,175,55,0.45);
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 16px;
      flex-wrap: wrap;
    }
    .brand h1 {
      font-size: clamp(18px, 4.5vw, 22px);
      font-weight: 300;
      letter-spacing: 3px;
      color: $_couleurOr;
      text-transform: uppercase;
    }
    .brand p {
      font-size: 11px;
      color: rgba(245,240,230,0.55);
      margin-top: 4px;
      letter-spacing: 1px;
    }
    .doc-ref {
      text-align: right;
      font-size: 11px;
      color: rgba(245,240,230,0.65);
    }
    .doc-ref strong {
      color: $_couleurOr;
      display: block;
      font-size: 13px;
      margin-bottom: 4px;
    }
    .content { padding: 20px 24px 28px; }
    .legal {
      font-size: 10px;
      font-style: italic;
      color: rgba(245,240,230,0.45);
      margin-bottom: 18px;
      padding-bottom: 14px;
      border-bottom: 1px solid rgba(212,175,55,0.25);
    }
    .section-title {
      font-size: 11px;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: $_couleurOr;
      margin: 18px 0 10px;
      font-weight: 600;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px 20px;
    }
    .field label {
      display: block;
      font-size: 9px;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      color: rgba(245,240,230,0.45);
      margin-bottom: 2px;
    }
    .field span {
      font-size: 13px;
      color: $_couleurTexte;
      word-break: break-word;
    }
    .field.full { grid-column: 1 / -1; }
    .tarif-box {
      margin-top: 20px;
      padding: 16px 20px;
      background: rgba(212,175,55,0.08);
      border: 1px solid rgba(212,175,55,0.35);
      border-radius: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 8px;
    }
    .tarif-box .montant {
      font-size: clamp(22px, 5vw, 26px);
      font-weight: 600;
      color: $_couleurOr;
      letter-spacing: 0.5px;
    }
    .tarif-box .libelle { font-size: 12px; color: rgba(245,240,230,0.7); }
    .table-wrap { overflow-x: auto; margin-top: 12px; -webkit-overflow-scrolling: touch; }
    table.facture {
      width: 100%;
      min-width: 520px;
      border-collapse: collapse;
      font-size: 12px;
    }
    table.facture th {
      text-align: left;
      padding: 8px 10px;
      background: rgba(212,175,55,0.12);
      color: $_couleurOr;
      font-size: 10px;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    table.facture td {
      padding: 10px;
      border-bottom: 1px solid rgba(245,240,230,0.08);
      vertical-align: top;
    }
    table.facture tr.total td {
      font-weight: 700;
      color: $_couleurOr;
      border-bottom: none;
      font-size: 14px;
    }
    .attestation {
      margin-top: 20px;
      padding: 12px 16px;
      background: rgba(255,255,255,0.04);
      border-radius: 8px;
      border-left: 3px solid $_couleurOr;
      font-size: 11px;
      color: rgba(245,240,230,0.75);
      line-height: 1.5;
    }
    .mentions-legales {
      margin-top: 22px;
      padding: 14px 16px;
      background: rgba(212,175,55,0.06);
      border: 1px solid rgba(212,175,55,0.22);
      border-radius: 8px;
    }
    .mentions-legales .field span { font-size: 12px; }
    .footer {
      padding: 16px 24px;
      background: rgba(0,0,0,0.25);
      border-top: 1px solid rgba(212,175,55,0.25);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 10px;
      font-size: 11px;
      color: rgba(245,240,230,0.55);
    }
    .footer a { color: $_couleurOr; text-decoration: none; }
    .footer .contact { display: flex; gap: 18px; flex-wrap: wrap; }
    @media (max-width: 600px) {
      body { padding: 12px; }
      .content { padding: 16px 16px 22px; }
      .header { padding: 18px 16px 14px; }
      .grid { grid-template-columns: 1fr; }
      .doc-ref { text-align: left; width: 100%; }
      .tarif-box { flex-direction: column; align-items: flex-start; }
    }
  </style>
</head>
<body>
  <div class="document">
    $corps
  </div>
</body>
</html>''';

  static String _htmlBonCommande(KeleganceDocumentDonnees d) {
    final modele = '''
    <div class="header">
      <div class="brand">
        <h1>{{raisonSociale}}</h1>
        <p>Chauffeur privé &amp; VTC premium</p>
      </div>
      <div class="doc-ref">
        <strong>{{titre}}</strong>
        Réf. {{numeroDocument}}<br>
        Émis le {{dateEmission}}
      </div>
    </div>
    <div class="content">
      <p class="legal">{{articleLegal}}</p>
      <p class="section-title">Chauffeur &amp; véhicule assignés</p>
      <div class="grid">
        <div class="field"><label>Chauffeur</label><span>{{chauffeurNom}}</span></div>
        <div class="field"><label>Téléphone</label><span>{{chauffeurTelephone}}</span></div>
        <div class="field"><label>Marque</label><span>{{chauffeurMarque}}</span></div>
        <div class="field"><label>Modèle</label><span>{{chauffeurModele}}</span></div>
        <div class="field"><label>Couleur</label><span>{{chauffeurCouleur}}</span></div>
        <div class="field"><label>Plaque</label><span>{{chauffeurPlaque}}</span></div>
      </div>
      <p class="section-title">Exploitant</p>
      <div class="grid">
        <div class="field"><label>Raison sociale</label><span>{{raisonSociale}}</span></div>
        <div class="field"><label>Contact administratif</label><span>{{emailAdmin}}</span></div>
      </div>
      <p class="section-title">Client &amp; réservation</p>
      <div class="grid">
        <div class="field"><label>Client</label><span>{{client}}</span></div>
        <div class="field"><label>E-mail</label><span>{{email}}</span></div>
        <div class="field"><label>Date de prise en charge</label><span>{{date}}</span></div>
        <div class="field"><label>Heure de récupération</label><span>{{heure}}</span></div>
        <div class="field full"><label>Lieu de prise en charge</label><span>{{depart}}</span></div>
        <div class="field full"><label>Destination</label><span>{{destination}}</span></div>
        <div class="field"><label>Passagers</label><span>{{passagers}}</span></div>
        <div class="field"><label>Prestation</label><span>{{prestation}}</span></div>
      </div>
      <div class="tarif-box">
        <div class="libelle">Tarif forfaitaire convenu (TTC)</div>
        <div class="montant">{{prixTtc}}</div>
      </div>
      <div class="attestation">
        Ce document atteste d'une réservation préalable effectuée par le client conformément
        à la réglementation VTC en vigueur. Le tarif affiché est définitif et sans supplément caché.
      </div>
      ${_blocMentionsLegales()}
    </div>
    <div class="footer">
      <span>Document électronique — token {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <span>{{chauffeurTelephone}}</span>
      </div>
    </div>''';
    return _remplacerVariables(modele, d);
  }

  static String _htmlFacture(KeleganceDocumentDonnees d) {
    final modele = '''
    <div class="header">
      <div class="brand">
        <h1>{{raisonSociale}}</h1>
        <p>Facturation électronique — transport VTC</p>
      </div>
      <div class="doc-ref">
        <strong>FACTURE TTC</strong>
        N° {{numeroDocument}}<br>
        Date : {{dateEmission}}
      </div>
    </div>
    <div class="content">
      <p class="legal">{{articleLegal}}</p>
      <p class="section-title">Émetteur</p>
      <div class="grid">
        <div class="field"><label>Exploitant</label><span>{{raisonSociale}}</span></div>
        <div class="field"><label>E-mail</label><span>{{emailAdmin}}</span></div>
        <div class="field"><label>WhatsApp Pro</label><span><a href="{{whatsappLien}}" style="color:#D4AF37">{{whatsapp}}</a></span></div>
      </div>
      <p class="section-title">Client</p>
      <div class="grid">
        <div class="field"><label>Nom / Référence</label><span>{{client}}</span></div>
        <div class="field"><label>E-mail</label><span>{{email}}</span></div>
      </div>
      <p class="section-title">Détail de la prestation</p>
      <div class="table-wrap">
      <table class="facture">
        <thead>
          <tr>
            <th>Description</th>
            <th>Date</th>
            <th>Trajet</th>
            <th style="text-align:right">Montant HT</th>
            <th style="text-align:right">TVA {{tauxTva}}%</th>
            <th style="text-align:right">TTC</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>{{prestation}}</td>
            <td>{{date}} {{heure}}</td>
            <td>{{depart}} → {{destination}}</td>
            <td style="text-align:right">{{prixHt}}</td>
            <td style="text-align:right">{{tva}}</td>
            <td style="text-align:right">{{prixTtc}}</td>
          </tr>
          <tr class="total">
            <td colspan="5" style="text-align:right">Total TTC</td>
            <td style="text-align:right">{{prixTtc}}</td>
          </tr>
        </tbody>
      </table>
      </div>
      <div class="attestation">
        Facture acquittée — prestation réalisée le {{date}} à {{heure}}.
        Passagers : {{passagers}}. TVA au taux de {{tauxTva}} % applicable aux transports de personnes.
        Paiement enregistré via Kélégance Prestige.
      </div>
      ${_blocMentionsLegales()}
    </div>
    <div class="footer">
      <span>Facture électronique — réf. {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <a href="{{whatsappLien}}">WhatsApp {{whatsapp}}</a>
      </div>
    </div>''';
    return _remplacerVariables(modele, d);
  }

  static String _echapper(String texte) => const HtmlEscape().convert(texte);
}

/// Identité légale & contacts documents — source unique facturation électronique.
abstract final class KeleganceIdentiteDocuments {
  static const String emailAdmin = 'admin@kelegance-prestige.com';
  static const String whatsappPrestige = '+33 6 00 00 00 00';
  static const String exploitant = 'KELEGANCE';
  static const String raisonSociale = 'KELEGANCE';
  static const String adresseSiege = '8 RUE AMPERE, 92000 NANTERRE FRANCE';
  static const String siret = '80484152600028';
  static const String numeroTva = 'Non assujetti';
  static const String codeApe = '4932Z';
  static const String conditionsReglement =
      'Paiement comptant à bord (carte bancaire ou espèces) ou virement sous 30 jours '
      'pour les comptes entreprise agréés. En l\'absence de paiement à l\'échéance, '
      'des pénalités de retard au taux légal seront applicables, ainsi qu\'une indemnité '
      'forfaitaire de 40 € pour frais de recouvrement (art. L.441-10 C. com.).';
  static const String prestationVtc = 'Transport Public Particulier de Personnes';

  static String get lienWhatsApp {
    final digits = whatsappPrestige.replaceAll(RegExp(r'\D'), '');
    return 'https://wa.me/$digits';
  }
}
