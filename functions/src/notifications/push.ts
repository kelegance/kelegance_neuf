import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

function firestore() {
  return admin.firestore();
}

type NotificationPrefs = {
  nouvelleMission?: boolean;
  rappelDepart1h?: boolean;
  facturePayee?: boolean;
};

type UserDoc = {
  fcmToken?: string;
  fcm_token?: string;
  email?: string;
  notificationPrefs?: NotificationPrefs;
};

export function estStatutPaye(statut?: string): boolean {
  const s = (statut ?? "").toUpperCase().replace(/É/g, "E").trim();
  return s.includes("PAYE") || s === "PAID" || s.includes("REGLE");
}

export function estStatutEligibleRappel(statut?: string): boolean {
  const s = (statut ?? "").toUpperCase();
  if (s.includes("ANNUL") || s.includes("TERMIN")) return false;
  return (
    s.includes("PLAN") ||
    s.includes("CONFIRM") ||
    s === "ACCEPTEE" ||
    s.includes("ATTENTE") ||
    s === "REDISPATCHÉ" ||
    s === "REDISPATCHE"
  );
}

export function extraireHorodatageMission(data: Record<string, unknown>): Date | null {
  const dateRaw = String(data.date ?? "").trim();
  const heureRaw = String(data.heure ?? data.heure_depart ?? "").trim();
  if (!dateRaw) return null;

  let year = 0;
  let month = 0;
  let day = 0;

  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(dateRaw);
  const slash = /^(\d{1,2})\/(\d{1,2})\/(\d{4})/.exec(dateRaw);
  if (iso) {
    year = Number(iso[1]);
    month = Number(iso[2]);
    day = Number(iso[3]);
  } else if (slash) {
    day = Number(slash[1]);
    month = Number(slash[2]);
    year = Number(slash[3]);
  } else {
    const parsed = Date.parse(dateRaw.split(" ")[0]);
    if (Number.isNaN(parsed)) return null;
    const d = new Date(parsed);
    year = d.getFullYear();
    month = d.getMonth() + 1;
    day = d.getDate();
  }

  let h = 0;
  let m = 0;
  const hm = /^(\d{1,2}):(\d{2})/.exec(heureRaw);
  if (hm) {
    h = Number(hm[1]);
    m = Number(hm[2]);
  }

  return new Date(year, month - 1, day, h, m, 0, 0);
}

export function libelleLieuMission(data: Record<string, unknown>): string {
  const parts = [
    String(data.depart ?? data.lieu_depart ?? "").trim(),
    String(data.destination ?? data.lieu_arrivee ?? "").trim(),
  ].filter(Boolean);
  return parts.join(" → ");
}

function prefsAutorise(prefs: NotificationPrefs | undefined, cle: keyof NotificationPrefs): boolean {
  if (!prefs) return true;
  const val = prefs[cle];
  return val !== false;
}

export async function resoudreTokensParEmail(emailBrut: string): Promise<string[]> {
  const email = emailBrut.toLowerCase().trim();
  if (!email) return [];

  const tokens = new Set<string>();

  const collect = (data: UserDoc | undefined) => {
    const token = data?.fcmToken || data?.fcm_token;
    if (token) tokens.add(token);
  };

  const users = await firestore().collection("users").where("email", "==", email).limit(5).get();
  users.forEach((doc) => collect(doc.data() as UserDoc));

  const chauffeurs = await firestore().collection("chauffeurs").where("email", "==", email).limit(5).get();
  chauffeurs.forEach((doc) => collect(doc.data() as UserDoc));

  return [...tokens];
}

export async function resoudreTokensParUid(uid: string): Promise<string[]> {
  const id = uid.trim();
  if (!id) return [];

  const tokens = new Set<string>();
  const collect = (data: UserDoc | undefined) => {
    const token = data?.fcmToken || data?.fcm_token;
    if (token) tokens.add(token);
  };

  for (const col of ["users", "chauffeurs"] as const) {
    const doc = await firestore().collection(col).doc(id).get();
    if (doc.exists) collect(doc.data() as UserDoc);
  }

  return [...tokens];
}

/** Résout les tokens FCM d'un chauffeur via UID, e-mail ou nom affiché. */
export async function resoudreTokensChauffeur(
  identifiant: string,
  uidHint?: string,
): Promise<string[]> {
  const tokens = new Set<string>();
  const id = identifiant.trim();

  if (uidHint) {
    for (const token of await resoudreTokensParUid(uidHint)) {
      tokens.add(token);
    }
  }

  if (id.includes("@")) {
    for (const token of await resoudreTokensParEmail(id)) {
      tokens.add(token);
    }
    if (tokens.size > 0) return [...tokens];
  }

  if (id.length >= 20 && !id.includes(" ") && !id.includes("@")) {
    for (const token of await resoudreTokensParUid(id)) {
      tokens.add(token);
    }
    if (tokens.size > 0) return [...tokens];
  }

  const needle = id.toLowerCase();
  if (needle.length >= 2) {
    const chauffeurs = await firestore().collection("chauffeurs").get();
    for (const doc of chauffeurs.docs) {
      const data = doc.data() as UserDoc & { name?: string };
      const name = String(data.name ?? "").toLowerCase().trim();
      const email = String(data.email ?? "").toLowerCase().trim();
      const match =
        (name && (name.includes(needle) || needle.includes(name))) ||
        (email && email === needle);
      if (!match) continue;
      for (const token of await resoudreTokensParUid(doc.id)) {
        tokens.add(token);
      }
      const direct = data.fcmToken || data.fcm_token;
      if (direct) tokens.add(direct);
    }
  }

  for (const token of await resoudreTokensParEmail(id)) {
    tokens.add(token);
  }

  return [...tokens];
}

export async function resoudreTokensBrasDroit(): Promise<{ token: string; prefs?: NotificationPrefs }[]> {
  const result: { token: string; prefs?: NotificationPrefs }[] = [];
  const seen = new Set<string>();

  for (const col of ["users", "chauffeurs"] as const) {
    const snap = await firestore().collection(col).get();
    for (const doc of snap.docs) {
      const data = doc.data() as UserDoc;
      const token = data.fcmToken || data.fcm_token;
      if (!token || seen.has(token)) continue;

      const role = String((data as Record<string, unknown>).role ?? "").toLowerCase();
      const niveau = String((data as Record<string, unknown>).niveauAcces ?? "").toLowerCase();
      const brasDroit =
        role.includes("admin") ||
        niveau.includes("bras") ||
        niveau.includes("complet") ||
        (data as Record<string, unknown>).brasDroit === true;

      if (!brasDroit) continue;
      seen.add(token);
      result.push({ token, prefs: data.notificationPrefs });
    }
  }

  return result;
}

const SON_NOUVELLE_COURSE_ANDROID = "nouvelle_course";
const SON_NOUVELLE_COURSE_IOS = "nouvelle_course.mp3";
const CANAL_NOUVELLE_COURSE = "kelegance_nouvelle_course";

function estNouvelleCourse(type?: string): boolean {
  return type === "nouvelle_mission" || type === "dispatch_sollicitation";
}

function optionsPushParType(type: string): Pick<admin.messaging.MulticastMessage, "android" | "apns"> {
  if (estNouvelleCourse(type)) {
    return {
      android: {
        priority: "high",
        notification: {
          channelId: CANAL_NOUVELLE_COURSE,
          sound: SON_NOUVELLE_COURSE_ANDROID,
          priority: "high" as const,
          defaultVibrateTimings: true,
          visibility: "public" as const,
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            sound: SON_NOUVELLE_COURSE_IOS,
            badge: 1,
            "content-available": 1,
          },
        },
      },
    };
  }
  return {
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  };
}

export async function envoyerFcm(
  tokens: string[],
  titre: string,
  corps: string,
  data: Record<string, string> = {},
): Promise<void> {
  const uniques = [...new Set(tokens.filter(Boolean))];
  if (uniques.length === 0) return;

  const type = data.type ?? "";
  const pushOptions = optionsPushParType(type);

  const message: admin.messaging.MulticastMessage = {
    tokens: uniques,
    notification: { title: titre, body: corps },
    data,
    ...pushOptions,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  if (response.failureCount > 0) {
    logger.warn("FCM échecs partiels", {
      succes: response.successCount,
      echecs: response.failureCount,
    });
  }
}

export async function notifierMissionAssignee(
  missionId: string,
  data: Record<string, unknown>,
  chauffeurAssigne: string,
): Promise<void> {
  const uidHint = String(
    data.chauffeurUid ?? data.chauffeurId ?? data.uidChauffeur ?? "",
  ).trim();
  const tokens = await resoudreTokensChauffeur(chauffeurAssigne, uidHint || undefined);
  if (tokens.length === 0) {
    logger.info("Aucun token FCM pour chauffeur", { missionId, chauffeurAssigne, uidHint });
    return;
  }

  const lieu = libelleLieuMission(data);
  await envoyerFcm(
    tokens,
    "Nouvelle mission",
    lieu ? `Course assignée : ${lieu}` : "Une course vous a été assignée.",
    { type: "nouvelle_mission", missionId },
  );
}

export async function notifierSollicitationDispatch(
  chauffeurUid: string,
  sollicitation: Record<string, unknown>,
): Promise<void> {
  const tokens = await resoudreTokensParUid(chauffeurUid);
  if (tokens.length === 0) {
    logger.info("Aucun token FCM pour sollicitation dispatch", { chauffeurUid });
    return;
  }

  const message =
    String(sollicitation.message ?? "").trim() ||
    "Nouvelle demande de course, es-tu disponible ?";

  await envoyerFcm(tokens, "KELEGANCE — Dispatch", message, {
    type: "dispatch_sollicitation",
    chauffeurUid,
  });
}

export async function notifierFacturePayee(
  factureId: string,
  data: Record<string, unknown>,
): Promise<void> {
  const destinataires = await resoudreTokensBrasDroit();
  const tokens = destinataires
    .filter((d) => prefsAutorise(d.prefs, "facturePayee"))
    .map((d) => d.token);

  if (tokens.length === 0) return;

  const numero = String(data.numero ?? factureId);
  const montant = String(data.montant ?? "");
  await envoyerFcm(
    tokens,
    "Facture payée",
    montant ? `Facture ${numero} — ${montant} €` : `Facture ${numero} payée`,
    { type: "facture_payee", factureId },
  );
}

export async function notifierNouvelleReservationHub(
  missionId: string,
  data: Record<string, unknown>,
): Promise<void> {
  const destinataires = await resoudreTokensBrasDroit();
  const tokens = destinataires
    .filter((d) => prefsAutorise(d.prefs, "nouvelleMission"))
    .map((d) => d.token);

  if (tokens.length === 0) {
    logger.info("Aucun token FCM Bras Droit pour réservation hub", { missionId });
    return;
  }

  const lieu = libelleLieuMission(data);
  const date = String(data.date ?? "");
  const heure = String(data.heure ?? "");
  const passagers = String(data.passagers ?? "1");
  const contact = String(data.contactHub ?? data.phone ?? data.email ?? "").trim();
  const corps = lieu
    ? `${date} ${heure} — ${lieu} (${passagers} pax${contact ? " · " + contact : ""})`
    : `Nouvelle demande carte QR — ${date} à ${heure}`;

  await envoyerFcm(tokens, "Nouvelle réservation QR", corps, {
    type: "reservation_hub",
    missionId,
  });
}

export async function scannerRappelsDepart1h(): Promise<number> {
  const maintenant = Date.now();
  const fenetreDebut = maintenant + 55 * 60 * 1000;
  const fenetreFin = maintenant + 65 * 60 * 1000;

  const snap = await firestore().collection("missions").get();
  let envoyes = 0;

  for (const doc of snap.docs) {
    const data = doc.data() as Record<string, unknown>;
    if (!estStatutEligibleRappel(String(data.statut ?? ""))) continue;
    if (data.rappelDepart1hEnvoye === true) continue;

    const rdv = extraireHorodatageMission(data);
    if (!rdv) continue;

    const t = rdv.getTime();
    if (t < fenetreDebut || t > fenetreFin) continue;

    const chauffeur = String(data.chauffeurAssigne ?? "").trim();
    const uidHint = String(data.chauffeurUid ?? data.chauffeurId ?? "").trim();
    const tokens = chauffeur
      ? await resoudreTokensChauffeur(chauffeur, uidHint || undefined)
      : [];

    const lieu = libelleLieuMission(data);
    const heure = String(data.heure ?? data.heure_depart ?? "");
    const corps = lieu
      ? `${lieu} — départ à ${heure}`
      : `Transfert planifié à ${heure}`;

    if (tokens.length > 0) {
      await envoyerFcm(tokens, "Départ dans 1 h", corps, {
        type: "rappel_depart_1h",
        missionId: doc.id,
      });
    }

    await doc.ref.set({ rappelDepart1hEnvoye: true, rappelDepart1hEnvoyeAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    envoyes++;
  }

  return envoyes;
}
