import { KELEGANCE_IDENTITE } from "../constants";

export interface MissionData {
  statut?: string;
  type?: string;
  client?: string;
  email?: string;
  depart?: string;
  destination?: string;
  date?: string;
  heure?: string;
  prix?: number;
  passagers?: number;
  chauffeurAssigne?: string;
  factureGeneree?: boolean | string;
  factureToken?: string;
  factureErreur?: string;
  factureEmailEnvoye?: boolean;
  bdcGeneree?: boolean | string;
  bdcErreur?: string;
  bdcEmailEnvoye?: boolean;
  bdcToken?: string;
  bdcType?: string;
}

export interface DocumentDonnees {
  type: string;
  token: string;
  titre: string;
  client: string;
  email: string;
  depart: string;
  destination: string;
  date: string;
  heure: string;
  prixTtc: number;
  prixHt: number;
  tva: number;
  netChauffeur: number;
  fraisService: number;
  passagers: number;
  numeroDocument: string;
  dateEmission: string;
  chauffeur?: string;
  missionId?: string;
}

export function normaliserStatut(statut: unknown): string {
  return String(statut ?? "")
    .trim()
    .toUpperCase()
    .replace(/É/g, "E");
}

export function estTerminee(statut: unknown): boolean {
  const s = normaliserStatut(statut);
  return s === "TERMINE" || s === "TERMINÉ";
}

export function texte(valeur: unknown, fallback = ""): string {
  const texte = String(valeur ?? "").trim();
  return texte || fallback;
}

export function genererToken(): string {
  const ts = Date.now();
  return `KDC-${ts.toString(36).toUpperCase()}-${(ts % 9999).toString().padStart(4, "0")}`;
}

export function formaterDateEmission(date = new Date()): string {
  const j = String(date.getDate()).padStart(2, "0");
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const a = date.getFullYear();
  return `${j}/${m}/${a}`;
}

export function ventilerCommission(prixTtc: number) {
  const fraisService = Math.round(prixTtc * 0.15 * 100) / 100;
  const netChauffeur = Math.round(prixTtc * 0.85 * 100) / 100;
  return { fraisService, netChauffeur };
}

export function documentDepuisMission(
  missionData: MissionData,
  options: { type: string; token: string; missionId: string; numeroDocument?: string },
): DocumentDonnees {
  const prixTtc = Number(missionData.prix ?? 0);
  const prixHt =
    Math.round((prixTtc / (1 + KELEGANCE_IDENTITE.tauxTvaTransport)) * 100) / 100;
  const tva = Math.round((prixTtc - prixHt) * 100) / 100;
  const { fraisService, netChauffeur } = ventilerCommission(prixTtc);
  const now = new Date();
  const dateEmission = formaterDateEmission(now);

  const titre =
    options.type === "BON DE COMMANDE RETOUR"
      ? "Bon de commande retour"
      : options.type === "BON DE COMMANDE VTC"
        ? "Bon de commande VTC"
        : "Facture TTC";

  const numeroDocument =
    options.numeroDocument ??
    (options.type === "FACTURE TTC"
      ? `FAC-${now.getFullYear()}-${options.token.substring(4, 12)}`
      : `BDC-${options.token.substring(4, 12)}`);

  return {
    type: options.type,
    token: options.token,
    titre,
    client: texte(missionData.client),
    email: texte(missionData.email, texte(missionData.client)),
    depart: texte(missionData.depart, "Non spécifié"),
    destination: texte(missionData.destination, "Non spécifiée"),
    date: texte(missionData.date, "—"),
    heure: texte(missionData.heure, "—"),
    prixTtc,
    prixHt,
    tva,
    netChauffeur,
    fraisService,
    passagers: Number(missionData.passagers ?? 1),
    numeroDocument,
    dateEmission,
    chauffeur: texte(missionData.chauffeurAssigne, "—"),
    missionId: options.missionId,
  };
}

export function estEmail(val: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val);
}

export function echapperHtml(texte: string): string {
  return texte
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function euros(montant: number): string {
  return `${montant.toFixed(2)} €`;
}

/** Type de bon de commande selon la mission (miroir app Flutter). */
export function typeBonCommandeMission(mission: MissionData): string {
  const t = String(mission.type ?? "")
    .toUpperCase()
    .replace(/É/g, "E");
  if (t.includes("RETOUR")) return "BON DE COMMANDE RETOUR";
  return "BON DE COMMANDE VTC";
}

export function titreDocument(type: string): string {
  if (type === "BON DE COMMANDE RETOUR") return "Bon de commande retour";
  if (type === "BON DE COMMANDE VTC") return "Bon de commande VTC";
  return "Facture TTC";
}
