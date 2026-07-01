/** Identité légale & contacts — miroir de kelegance_documents_pdf_service.dart */
export const KELEGANCE_IDENTITE = {
  emailAdmin: "admin@kelegance-prestige.com",
  whatsappPrestige: "+33 6 00 00 00 00",
  exploitant: "KELEGANCE",
  raisonSociale: "KELEGANCE",
  adresseSiege: "8 RUE AMPERE, 92000 NANTERRE FRANCE",
  siret: "80484152600028",
  numeroTva: "Non assujetti",
  codeApe: "4932Z",
  conditionsReglement:
    "Paiement comptant à bord (carte bancaire ou espèces) ou virement sous 30 jours " +
    "pour les comptes entreprise agréés. En l'absence de paiement à l'échéance, " +
    "des pénalités de retard au taux légal seront applicables, ainsi qu'une indemnité " +
    "forfaitaire de 40 € pour frais de recouvrement (art. L.441-10 C. com.).",
  prestationVtc: "Transport Public Particulier de Personnes",
  baseUrlWeb: "https://kelegance.web.app/doc",
  tauxTvaTransport: 0.1,
  articleLegal:
    "Document de conformité réglementaire — Article L. 3122-9 du Code des transports",
} as const;

export const WHATSAPP_LIEN = `https://wa.me/${KELEGANCE_IDENTITE.whatsappPrestige.replace(/\D/g, "")}`;
