import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Données réservation extraites d'une mission Firestore — injectées dans HTML / PDF.
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

  static const double tauxTvaTransport = 0.10;

  factory KeleganceDocumentDonnees.depuisMission(
    Map<String, dynamic> missionData, {
    required String type,
    required String token,
    String? numeroDocument,
    String? missionId,
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
      chauffeur: missionData['chauffeurAssigne']?.toString(),
      missionId: missionId,
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

/// Génération HTML & PDF — charte KELEGANCE (minuit bleu / or premium).
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
    final corps = switch (type) {
      'BON DE COMMANDE RETOUR' || 'BON DE COMMANDE VTC' => _htmlBonCommande(donnees),
      _ => _htmlFacture(donnees),
    };
    return _enveloppeHtml(donnees.titre.toUpperCase(), corps);
  }

  static Future<List<int>> genererPdf({
    required String type,
    required KeleganceDocumentDonnees donnees,
  }) async {
    final doc = pw.Document();
    final couleurOr = PdfColor.fromHex(_couleurOr);
    final couleurTexte = PdfColor.fromHex(_couleurTexte);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: couleurOr, width: 1.2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _pdfEntete(donnees, couleurOr, couleurTexte),
                pw.SizedBox(height: 18),
                pw.Divider(color: couleurOr, thickness: 0.8),
                pw.SizedBox(height: 14),
                if (type == 'FACTURE TTC')
                  ..._pdfCorpsFacture(donnees, couleurOr, couleurTexte)
                else
                  ..._pdfCorpsBonCommande(donnees, couleurOr, couleurTexte),
                pw.Spacer(),
                _pdfPiedDePage(couleurOr, couleurTexte),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
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
        '{{dateEmission}}': _echapper(d.dateEmission),
        '{{emailAdmin}}': _echapper(emailAdmin),
        '{{whatsapp}}': _echapper(whatsappPrestige),
        '{{whatsappLien}}': KeleganceIdentiteDocuments.lienWhatsApp,
        '{{articleLegal}}': _echapper(_articleLegal),
        '{{chauffeur}}': _echapper(d.chauffeur ?? '—'),
      };

  static String _remplacerVariables(String modele, KeleganceDocumentDonnees d) {
    var html = modele;
    for (final entree in variablesHtml(d).entries) {
      html = html.replaceAll(entree.key, entree.value);
    }
    return html;
  }

  static String _enveloppeHtml(String titrePage, String corps) => '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$titrePage — KELEGANCE PRESTIGE</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
      background: $_couleurFond;
      color: $_couleurTexte;
      line-height: 1.5;
      padding: 24px;
    }
    .document {
      max-width: 720px;
      margin: 0 auto;
      background: linear-gradient(145deg, $_couleurFondClair 0%, $_couleurFond 100%);
      border: 1px solid $_couleurOr;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 8px 32px rgba(0,0,0,0.45);
    }
    .header {
      padding: 28px 32px 20px;
      border-bottom: 1px solid rgba(212,175,55,0.45);
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 16px;
    }
    .brand h1 {
      font-size: 22px;
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
    .doc-ref strong { color: $_couleurOr; display: block; font-size: 13px; margin-bottom: 4px; }
    .content { padding: 24px 32px 32px; }
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
      gap: 10px 24px;
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
    }
    .tarif-box .montant {
      font-size: 26px;
      font-weight: 600;
      color: $_couleurOr;
      letter-spacing: 0.5px;
    }
    .tarif-box .libelle { font-size: 12px; color: rgba(245,240,230,0.7); }
    table.facture {
      width: 100%;
      border-collapse: collapse;
      margin-top: 12px;
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
    }
    .footer {
      padding: 18px 32px;
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
    .footer a {
      color: $_couleurOr;
      text-decoration: none;
    }
    .footer .contact { display: flex; gap: 18px; flex-wrap: wrap; }
    @media print {
      body { background: white; padding: 0; }
      .document { box-shadow: none; border-radius: 0; }
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
        <h1>Kelegance Prestige</h1>
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
      <p class="section-title">Exploitant</p>
      <div class="grid">
        <div class="field"><label>Raison sociale</label><span>{{exploitant}}</span></div>
        <div class="field"><label>Contact</label><span>{{emailAdmin}}</span></div>
        <div class="field"><label>WhatsApp Pro</label><span><a href="{{whatsappLien}}" style="color:#D4AF37">{{whatsapp}}</a></span></div>
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
        <div class="field"><label>Chauffeur assigné</label><span>{{chauffeur}}</span></div>
      </div>
      <div class="tarif-box">
        <div class="libelle">Tarif forfaitaire convenu (TTC)</div>
        <div class="montant">{{prixTtc}}</div>
      </div>
      <div class="attestation">
        Ce document atteste d'une réservation préalable effectuée par le client conformément
        à la réglementation VTC en vigueur. Le tarif affiché est définitif et sans supplément caché.
      </div>
    </div>
    <div class="footer">
      <span>Token sécurisé : {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <a href="{{whatsappLien}}">WhatsApp {{whatsapp}}</a>
      </div>
    </div>''';
    return _remplacerVariables(modele, d);
  }

  static String _htmlFacture(KeleganceDocumentDonnees d) {
    final modele = '''
    <div class="header">
      <div class="brand">
        <h1>Kelegance Prestige</h1>
        <p>Facturation transport VTC</p>
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
        <div class="field"><label>Exploitant</label><span>{{exploitant}}</span></div>
        <div class="field"><label>E-mail</label><span>{{emailAdmin}}</span></div>
        <div class="field"><label>WhatsApp Pro</label><span><a href="{{whatsappLien}}" style="color:#D4AF37">{{whatsapp}}</a></span></div>
      </div>
      <p class="section-title">Client</p>
      <div class="grid">
        <div class="field"><label>Nom / Référence</label><span>{{client}}</span></div>
        <div class="field"><label>E-mail</label><span>{{email}}</span></div>
      </div>
      <p class="section-title">Détail de la prestation</p>
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
      <div class="attestation">
        Facture acquittée — prestation réalisée le {{date}} à {{heure}}.
        Passagers : {{passagers}}. Paiement enregistré via Kélégance Prestige.
      </div>
    </div>
    <div class="footer">
      <span>Réf. mission {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <a href="{{whatsappLien}}">WhatsApp {{whatsapp}}</a>
      </div>
    </div>''';
    return _remplacerVariables(modele, d);
  }

  static String _echapper(String texte) => const HtmlEscape().convert(texte);

  static pw.Widget _pdfEntete(
    KeleganceDocumentDonnees d,
    PdfColor or,
    PdfColor texte,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'KELEGANCE PRESTIGE',
              style: pw.TextStyle(color: or, fontSize: 18, letterSpacing: 2),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              d.titre,
              style: pw.TextStyle(color: texte, fontSize: 10),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(d.numeroDocument, style: pw.TextStyle(color: or, fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Émis le ${d.dateEmission}', style: pw.TextStyle(color: texte, fontSize: 9)),
          ],
        ),
      ],
    );
  }

  static List<pw.Widget> _pdfCorpsBonCommande(
    KeleganceDocumentDonnees d,
    PdfColor or,
    PdfColor texte,
  ) {
    return [
      pw.Text(_articleLegal, style: pw.TextStyle(color: texte, fontSize: 8, fontStyle: pw.FontStyle.italic)),
      pw.SizedBox(height: 12),
      ..._pdfLigne('Client', d.client, or, texte),
      ..._pdfLigne('E-mail', d.email, or, texte),
      ..._pdfLigne('Date', d.date, or, texte),
      ..._pdfLigne('Heure', d.heure, or, texte),
      ..._pdfLigne('Lieu de prise en charge', d.depart, or, texte),
      ..._pdfLigne('Destination', d.destination, or, texte),
      ..._pdfLigne('Passagers', d.passagers.toString(), or, texte),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: or),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Tarif TTC convenu', style: pw.TextStyle(color: texte, fontSize: 11)),
            pw.Text(d.prixTtcFormate, style: pw.TextStyle(color: or, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    ];
  }

  static List<pw.Widget> _pdfCorpsFacture(
    KeleganceDocumentDonnees d,
    PdfColor or,
    PdfColor texte,
  ) {
    return [
      ..._pdfLigne('Client', d.client, or, texte),
      ..._pdfLigne('E-mail', d.email, or, texte),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: or, width: 0.3),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#121E33')),
            children: [
              _pdfCell('Prestation', or, bold: true),
              _pdfCell('HT', or, bold: true),
              _pdfCell('TVA 10%', or, bold: true),
              _pdfCell('TTC', or, bold: true),
            ],
          ),
          pw.TableRow(
            children: [
              _pdfCell('${d.depart} → ${d.destination}\n${d.date} ${d.heure}', texte),
              _pdfCell(d.prixHtFormate, texte),
              _pdfCell(d.tvaFormate, texte),
              _pdfCell(d.prixTtcFormate, texte),
            ],
          ),
          pw.TableRow(
            children: [
              _pdfCell('TOTAL', or, bold: true),
              _pdfCell('', texte),
              _pdfCell('', texte),
              _pdfCell(d.prixTtcFormate, or, bold: true),
            ],
          ),
        ],
      ),
    ];
  }

  static pw.Widget _pdfCell(String texte, PdfColor couleur, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        texte,
        style: pw.TextStyle(
          color: couleur,
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static List<pw.Widget> _pdfLigne(String label, String valeur, PdfColor or, PdfColor texte) {
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: pw.TextStyle(color: or, fontSize: 9, letterSpacing: 0.5)),
          ),
          pw.Expanded(child: pw.Text(valeur, style: pw.TextStyle(color: texte, fontSize: 10))),
        ],
      ),
      pw.SizedBox(height: 5),
    ];
  }

  static pw.Widget _pdfPiedDePage(PdfColor or, PdfColor texte) {
    return pw.Column(
      children: [
        pw.Divider(color: or),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(emailAdmin, style: pw.TextStyle(color: or, fontSize: 9)),
            pw.Text(whatsappPrestige, style: pw.TextStyle(color: texte, fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          KeleganceIdentiteDocuments.exploitant,
          style: pw.TextStyle(color: texte, fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}

/// Identité légale & contacts documents — source unique charte KELEGANCE.
abstract final class KeleganceIdentiteDocuments {
  static const String emailAdmin = 'admin@kelegance-prestige.com';
  static const String whatsappPrestige = '+33 6 65 58 73 60';
  static const String exploitant = 'KELEGANCE PRESTIGE';
  static const String prestationVtc = 'Transport Public Particulier de Personnes';

  static String get lienWhatsApp {
    final digits = whatsappPrestige.replaceAll(RegExp(r'\D'), '');
    return 'https://wa.me/$digits';
  }
}
