import { KELEGANCE_IDENTITE, WHATSAPP_LIEN } from "../constants";
import { DocumentDonnees, echapperHtml, euros } from "../utils/mission";

function remplacerVariables(modele: string, d: DocumentDonnees): string {
  const vars: Record<string, string> = {
    "{{titre}}": echapperHtml(d.titre.toUpperCase()),
    "{{numeroDocument}}": echapperHtml(d.numeroDocument),
    "{{token}}": echapperHtml(d.token),
    "{{client}}": echapperHtml(d.client),
    "{{email}}": echapperHtml(d.email),
    "{{date}}": echapperHtml(d.date),
    "{{heure}}": echapperHtml(d.heure),
    "{{depart}}": echapperHtml(d.depart),
    "{{destination}}": echapperHtml(d.destination),
    "{{passagers}}": String(d.passagers),
    "{{prixTtc}}": echapperHtml(euros(d.prixTtc)),
    "{{prixHt}}": echapperHtml(euros(d.prixHt)),
    "{{tva}}": echapperHtml(euros(d.tva)),
    "{{tauxTva}}": "10",
    "{{prestation}}": echapperHtml(KELEGANCE_IDENTITE.prestationVtc),
    "{{exploitant}}": echapperHtml(KELEGANCE_IDENTITE.exploitant),
    "{{raisonSociale}}": echapperHtml(KELEGANCE_IDENTITE.raisonSociale),
    "{{siret}}": echapperHtml(KELEGANCE_IDENTITE.siret),
    "{{adresseSiege}}": echapperHtml(KELEGANCE_IDENTITE.adresseSiege),
    "{{numeroTva}}": echapperHtml(KELEGANCE_IDENTITE.numeroTva),
    "{{codeApe}}": echapperHtml(KELEGANCE_IDENTITE.codeApe),
    "{{conditionsReglement}}": echapperHtml(KELEGANCE_IDENTITE.conditionsReglement),
    "{{dateEmission}}": echapperHtml(d.dateEmission),
    "{{emailAdmin}}": echapperHtml(KELEGANCE_IDENTITE.emailAdmin),
    "{{whatsapp}}": echapperHtml(KELEGANCE_IDENTITE.whatsappPrestige),
    "{{whatsappLien}}": WHATSAPP_LIEN,
    "{{articleLegal}}": echapperHtml(KELEGANCE_IDENTITE.articleLegal),
    "{{chauffeur}}": echapperHtml(d.chauffeur ?? "—"),
  };

  let html = modele;
  for (const [cle, valeur] of Object.entries(vars)) {
    html = html.split(cle).join(valeur);
  }
  return html;
}

const BLOC_MENTIONS_LEGALES = `
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
      </div>`;

function enveloppeHtml(titrePage: string, corps: string): string {
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="#0B1426">
  <title>${echapperHtml(titrePage)} — KELEGANCE PRESTIGE</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html { -webkit-text-size-adjust: 100%; }
    body {
      font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
      background: #0B1426;
      color: #F5F0E6;
      line-height: 1.55;
      padding: max(16px, env(safe-area-inset-top)) 16px max(24px, env(safe-area-inset-bottom));
      min-height: 100vh;
    }
    .document {
      max-width: 760px;
      margin: 0 auto;
      background: linear-gradient(145deg, #121E33 0%, #0B1426 100%);
      border: 1px solid #D4AF37;
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
      color: #D4AF37;
      text-transform: uppercase;
    }
    .brand p { font-size: 11px; color: rgba(245,240,230,0.55); margin-top: 4px; letter-spacing: 1px; }
    .doc-ref { text-align: right; font-size: 11px; color: rgba(245,240,230,0.65); }
    .doc-ref strong { color: #D4AF37; display: block; font-size: 13px; margin-bottom: 4px; }
    .content { padding: 20px 24px 28px; }
    .legal {
      font-size: 10px; font-style: italic; color: rgba(245,240,230,0.45);
      margin-bottom: 18px; padding-bottom: 14px;
      border-bottom: 1px solid rgba(212,175,55,0.25);
    }
    .section-title {
      font-size: 11px; letter-spacing: 2px; text-transform: uppercase;
      color: #D4AF37; margin: 18px 0 10px; font-weight: 600;
    }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 20px; }
    .field label {
      display: block; font-size: 9px; letter-spacing: 1.2px; text-transform: uppercase;
      color: rgba(245,240,230,0.45); margin-bottom: 2px;
    }
    .field span { font-size: 13px; color: #F5F0E6; word-break: break-word; }
    .field.full { grid-column: 1 / -1; }
    .table-wrap { overflow-x: auto; margin-top: 12px; -webkit-overflow-scrolling: touch; }
    table.facture { width: 100%; min-width: 520px; border-collapse: collapse; font-size: 12px; }
    table.facture th {
      text-align: left; padding: 8px 10px; background: rgba(212,175,55,0.12);
      color: #D4AF37; font-size: 10px; letter-spacing: 1px; text-transform: uppercase;
    }
    table.facture td { padding: 10px; border-bottom: 1px solid rgba(245,240,230,0.08); vertical-align: top; }
    table.facture tr.total td { font-weight: 700; color: #D4AF37; border-bottom: none; font-size: 14px; }
    .attestation {
      margin-top: 20px; padding: 12px 16px; background: rgba(255,255,255,0.04);
      border-radius: 8px; border-left: 3px solid #D4AF37;
      font-size: 11px; color: rgba(245,240,230,0.75); line-height: 1.5;
    }
    .mentions-legales {
      margin-top: 22px; padding: 14px 16px;
      background: rgba(212,175,55,0.06); border: 1px solid rgba(212,175,55,0.22);
      border-radius: 8px;
    }
    .mentions-legales .field span { font-size: 12px; }
    .footer {
      padding: 16px 24px; background: rgba(0,0,0,0.25);
      border-top: 1px solid rgba(212,175,55,0.25);
      display: flex; justify-content: space-between; align-items: center;
      flex-wrap: wrap; gap: 10px; font-size: 11px; color: rgba(245,240,230,0.55);
    }
    .footer a { color: #D4AF37; text-decoration: none; }
    .footer .contact { display: flex; gap: 18px; flex-wrap: wrap; }
    .tarif-box {
      margin-top: 20px; padding: 16px 20px;
      background: rgba(212,175,55,0.08); border: 1px solid rgba(212,175,55,0.35);
      border-radius: 8px; display: flex; justify-content: space-between;
      align-items: center; flex-wrap: wrap; gap: 8px;
    }
    .tarif-box .libelle { font-size: 12px; color: rgba(245,240,230,0.7); }
    .tarif-box .montant {
      font-size: clamp(22px, 5vw, 26px); font-weight: 600; color: #D4AF37;
    }
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
  <div class="document">${corps}</div>
</body>
</html>`;
}

const MODELE_FACTURE = `
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
      ${BLOC_MENTIONS_LEGALES}
    </div>
    <div class="footer">
      <span>Facture électronique — réf. {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <a href="{{whatsappLien}}">WhatsApp {{whatsapp}}</a>
      </div>
    </div>`;

export function genererHtmlFacture(donnees: DocumentDonnees): string {
  const corps = remplacerVariables(MODELE_FACTURE, donnees);
  return enveloppeHtml(donnees.titre.toUpperCase(), corps);
}

const MODELE_BON_COMMANDE = `
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
      <p class="section-title">Exploitant</p>
      <div class="grid">
        <div class="field"><label>Raison sociale</label><span>{{raisonSociale}}</span></div>
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
      ${BLOC_MENTIONS_LEGALES}
    </div>
    <div class="footer">
      <span>Document électronique — token {{token}}</span>
      <div class="contact">
        <a href="mailto:{{emailAdmin}}">{{emailAdmin}}</a>
        <a href="{{whatsappLien}}">WhatsApp {{whatsapp}}</a>
      </div>
    </div>`;

export function genererHtmlBonCommande(donnees: DocumentDonnees): string {
  const corps = remplacerVariables(MODELE_BON_COMMANDE, donnees);
  return enveloppeHtml(donnees.titre.toUpperCase(), corps);
}

export function genererHtmlDocument(type: string, donnees: DocumentDonnees): string {
  if (type === "FACTURE TTC") return genererHtmlFacture(donnees);
  return genererHtmlBonCommande(donnees);
}
