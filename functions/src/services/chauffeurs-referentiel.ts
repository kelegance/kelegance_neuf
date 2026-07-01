import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import * as logger from "firebase-functions/logger";
import { MissionData } from "../utils/mission";

export interface ProfilChauffeurBdc {
  nom: string;
  telephone: string;
  marque: string;
  modele: string;
  couleur: string;
  plaque: string;
  email?: string;
  uid?: string;
  cle?: string;
}

export class ChauffeurDonneesIncompletesError extends Error {
  constructor(detail?: string) {
    super(detail ? `Données chauffeur incomplètes — ${detail}` : "Données chauffeur incomplètes");
    this.name = "ChauffeurDonneesIncompletesError";
  }
}

type ChauffeurJson = {
  cle?: string;
  nom?: string;
  email?: string;
  aliases?: string[];
  telephone?: string;
  marque?: string;
  modele?: string;
  couleur?: string;
  plaque?: string;
};

let cacheJson: ChauffeurJson[] | null = null;

function chargerJson(): ChauffeurJson[] {
  if (cacheJson) return cacheJson;
  const fichier = path.join(__dirname, "..", "data", "chauffeurs_data.json");
  const brut = fs.readFileSync(fichier, "utf8");
  const parsed = JSON.parse(brut) as { chauffeurs?: ChauffeurJson[] };
  cacheJson = parsed.chauffeurs ?? [];
  return cacheJson;
}

function normaliser(raw?: string): string {
  return String(raw ?? "")
    .toLowerCase()
    .trim()
    .replace(/é/g, "e")
    .replace(/è/g, "e");
}

function depuisMap(data: Record<string, unknown>, uid?: string): ProfilChauffeurBdc | null {
  const profil: ProfilChauffeurBdc = {
    nom: String(data.nom ?? "").trim(),
    telephone: String(data.telephone ?? data.phone ?? "").trim(),
    marque: String(data.marque ?? "").trim(),
    modele: String(data.modele ?? "").trim(),
    couleur: String(data.couleur ?? "").trim(),
    plaque: String(data.plaque ?? data.immatriculation ?? "").trim(),
    email: data.email ? String(data.email).toLowerCase().trim() : undefined,
    uid,
    cle: data.cle ? String(data.cle) : undefined,
  };
  if (
    !profil.nom ||
    !profil.telephone ||
    !profil.marque ||
    !profil.modele ||
    !profil.couleur ||
    !profil.plaque
  ) {
    return null;
  }
  return profil;
}

async function parUidFirestore(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<ProfilChauffeurBdc | null> {
  for (const col of ["profils_chauffeur", "chauffeurs", "users"] as const) {
    const doc = await db.collection(col).doc(uid).get();
    if (!doc.exists) continue;
    const profil = depuisMap(doc.data() as Record<string, unknown>, uid);
    if (profil) return profil;
  }
  return null;
}

async function parEmailFirestore(
  db: admin.firestore.Firestore,
  email: string,
): Promise<ProfilChauffeurBdc | null> {
  const mail = email.toLowerCase().trim();
  if (!mail.includes("@")) return null;
  for (const col of ["profils_chauffeur", "chauffeurs", "users"] as const) {
    const snap = await db.collection(col).where("email", "==", mail).limit(1).get();
    if (snap.empty) continue;
    const profil = depuisMap(snap.docs[0].data() as Record<string, unknown>, snap.docs[0].id);
    if (profil) return profil;
  }
  return null;
}

function parJson(identifiant: string): ProfilChauffeurBdc | null {
  const needle = normaliser(identifiant);
  if (!needle) return null;
  for (const entry of chargerJson()) {
    const email = normaliser(entry.email);
    const nom = normaliser(entry.nom);
    const cle = normaliser(entry.cle);
    const aliases = (entry.aliases ?? []).map((a) => normaliser(a));
    const match =
      needle === email ||
      needle === nom ||
      needle === cle ||
      aliases.includes(needle) ||
      (nom && (nom.includes(needle) || needle.includes(nom))) ||
      (email && needle.includes(email));
    if (match) return depuisMap(entry as Record<string, unknown>);
  }
  return null;
}

export async function resoudreProfilChauffeur(
  db: admin.firestore.Firestore,
  mission: MissionData,
): Promise<ProfilChauffeurBdc | null> {
  const uid = String(
    mission.chauffeurUid ?? mission.chauffeurId ?? (mission as Record<string, unknown>).uidChauffeur ?? "",
  ).trim();
  const assigne = String(mission.chauffeurAssigne ?? "").trim();

  if (uid) {
    const firestore = await parUidFirestore(db, uid);
    if (firestore) return firestore;
  }

  if (assigne) {
    if (assigne.includes("@")) {
      const parEmail = await parEmailFirestore(db, assigne);
      if (parEmail) return parEmail;
    }
    const json = parJson(assigne);
    if (json) return json;
  }

  if (uid) return parJson(uid);
  return null;
}

export async function exigerProfilChauffeur(
  db: admin.firestore.Firestore,
  mission: MissionData,
): Promise<ProfilChauffeurBdc> {
  const profil = await resoudreProfilChauffeur(db, mission);
  if (!profil) {
    const assigne = String(mission.chauffeurAssigne ?? "—");
    throw new ChauffeurDonneesIncompletesError(
      `Aucun profil complet pour « ${assigne} ». Assignez un chauffeur référencé.`,
    );
  }
  logger.info("Profil chauffeur BDC résolu", {
    missionId: (mission as Record<string, unknown>).id,
    chauffeur: profil.nom,
    plaque: profil.plaque,
  });
  return profil;
}
