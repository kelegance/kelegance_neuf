/** Identité légale & contacts — miroir de kelegance_documents_pdf_service.dart */
export const KELEGANCE_IDENTITE = {
  emailAdmin: "admin@kelegance-prestige.com",
  whatsappPrestige: "+33 6 65 58 73 60",
  exploitant: "KELEGANCE PRESTIGE",
  prestationVtc: "Transport Public Particulier de Personnes",
  baseUrlWeb: "https://kelegance.web.app/doc",
  tauxTvaTransport: 0.1,
  articleLegal:
    "Document de conformité réglementaire — Article L. 3122-9 du Code des transports",
} as const;

export const WHATSAPP_LIEN = `https://wa.me/${KELEGANCE_IDENTITE.whatsappPrestige.replace(/\D/g, "")}`;
