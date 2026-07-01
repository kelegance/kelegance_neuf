import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { FieldValue } from "firebase-admin/firestore";
import { KELEGANCE_IDENTITE } from "../constants";
import { genererHtmlDocument } from "./invoice-html";
import { exigerProfilChauffeur } from "../services/chauffeurs-referentiel";
import {
  DocumentDonnees,
  MissionData,
  documentDepuisMission,
  estEmail,
  formaterDateEmission,
  genererToken,
  texte,
  titreDocument,
  ventilerCommission,
} from "../utils/mission";

export interface DocumentPublie {
  type: string;
  token: string;
  lienWeb: string;
  numeroDocument: string;
  htmlContenu: string;
  emailClient: string;
  donnees: DocumentDonnees;
}

export async function resoudreEmailClient(
  db: admin.firestore.Firestore,
  mission: MissionData,
): Promise<string> {
  const candidats = [mission.email, mission.client].filter(Boolean).map(String);
  for (const valeur of candidats) {
    if (estEmail(valeur)) return valeur.toLowerCase();
  }

  const clientRef = texte(mission.client);
  if (!clientRef) return "";

  try {
    if (estEmail(clientRef)) return clientRef.toLowerCase();

    const byEmail = await db
      .collection("users")
      .where("email", "==", clientRef.toLowerCase())
      .limit(1)
      .get();
    if (!byEmail.empty) {
      const email = byEmail.docs[0].data().email;
      if (email) return String(email).toLowerCase();
    }

    const byName = await db
      .collection("users")
      .where("name", "==", clientRef.toUpperCase())
      .limit(1)
      .get();
    if (!byName.empty) {
      const email = byName.docs[0].data().email;
      if (email) return String(email).toLowerCase();
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logger.warn("Résolution e-mail via users ignorée", { message, clientRef });
  }

  return "";
}

export async function documentExisteDeja(
  db: admin.firestore.Firestore,
  missionId: string,
  type: string,
): Promise<boolean> {
  const existant = await db
    .collection("documents_client")
    .where("missionId", "==", missionId)
    .where("type", "==", type)
    .limit(1)
    .get();
  if (existant.empty) return false;
  const data = existant.docs[0].data();
  return Boolean(data.htmlContenu);
}

/** Publie un document client dans Firestore — facturation 100 % électronique (HTML web). */
export async function publierDocument(
  db: admin.firestore.Firestore,
  missionId: string,
  missionData: MissionData,
  type: string,
  emailClient: string,
): Promise<DocumentPublie> {
  const token = genererToken();
  const lienWeb = `${KELEGANCE_IDENTITE.baseUrlWeb}/${token}`;
  const estBdc = type !== "FACTURE TTC";
  const profilChauffeur = estBdc ? await exigerProfilChauffeur(db, missionData) : undefined;
  const donnees = documentDepuisMission(missionData, {
    type,
    token,
    missionId,
    profilChauffeur,
  });
  const htmlContenu = genererHtmlDocument(type, donnees);
  const prix = donnees.prixTtc;
  const ventilation = ventilerCommission(prix);

  const docPayload: Record<string, unknown> = {
    token,
    type,
    titre: titreDocument(type),
    lienWeb,
    missionId,
    client: missionData.client ?? "",
    email: emailClient || missionData.email || missionData.client || "",
    depart: missionData.depart ?? "",
    destination: missionData.destination ?? "",
    date: missionData.date ?? "",
    heure: missionData.heure ?? "",
    passagers: donnees.passagers,
    prixTtc: prix,
    prixHt: donnees.prixHt,
    tva: donnees.tva,
    netChauffeur: ventilation.netChauffeur,
    fraisService: ventilation.fraisService,
    numeroDocument: donnees.numeroDocument,
    dateEmission: donnees.dateEmission,
    chauffeur: donnees.chauffeurNom ?? donnees.chauffeur,
    chauffeurVehicule: donnees.chauffeurVehicule,
    chauffeurPlaque: donnees.chauffeurPlaque,
    htmlContenu,
    format: "electronique_web",
    emailAdmin: KELEGANCE_IDENTITE.emailAdmin,
    whatsappPrestige: KELEGANCE_IDENTITE.whatsappPrestige,
    statut: "publie",
    source: "cloud_function_documents_auto",
    createdAt: FieldValue.serverTimestamp(),
  };

  await db.collection("documents_client").doc(token).set(docPayload);

  if (type === "FACTURE TTC") {
    await db.collection("factures").add({
      numero: donnees.numeroDocument,
      client: missionData.client ?? "CLIENT INCONNU",
      email: emailClient,
      montant: prix.toFixed(2),
      date: formaterDateEmission(),
      statut: "PUBLIÉ",
      lienWeb,
      tokenDocument: token,
      missionId,
      source: "CLOUD_FUNCTION_DOCUMENTS_AUTO",
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return {
    type,
    token,
    lienWeb,
    numeroDocument: donnees.numeroDocument,
    htmlContenu,
    emailClient,
    donnees,
  };
}

export async function publierFactureTtc(
  db: admin.firestore.Firestore,
  missionId: string,
  missionData: MissionData,
  emailClient: string,
): Promise<DocumentPublie> {
  return publierDocument(db, missionId, missionData, "FACTURE TTC", emailClient);
}

export async function factureExisteDeja(
  db: admin.firestore.Firestore,
  missionId: string,
): Promise<boolean> {
  return documentExisteDeja(db, missionId, "FACTURE TTC");
}

export async function chargerDocumentExistant(
  db: admin.firestore.Firestore,
  missionId: string,
  type: string,
): Promise<DocumentPublie | null> {
  const snap = await db
    .collection("documents_client")
    .where("missionId", "==", missionId)
    .where("type", "==", type)
    .limit(1)
    .get();
  if (snap.empty) return null;

  const data = snap.docs[0].data();
  if (!data.htmlContenu) return null;

  return {
    type,
    token: String(data.token),
    lienWeb: String(data.lienWeb),
    numeroDocument: String(data.numeroDocument),
    htmlContenu: String(data.htmlContenu),
    emailClient: String(data.email ?? ""),
    donnees: documentDepuisMission(
      {
        client: data.client,
        email: data.email,
        depart: data.depart,
        destination: data.destination,
        date: data.date,
        heure: data.heure,
        prix: data.prixTtc,
        passagers: data.passagers,
        chauffeurAssigne: data.chauffeur,
      },
      { type, token: String(data.token), missionId },
    ),
  };
}

export type FacturePubliee = DocumentPublie;
