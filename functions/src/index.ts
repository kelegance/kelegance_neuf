import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import { envoyerFactureParEmail, envoyerAlerteReservationHub } from "./email/mailer";
import {
  chargerDocumentExistant,
  documentExisteDeja,
  publierDocument,
  resoudreEmailClient,
} from "./documents/invoice-service";
import { traiterBonCommandeMission } from "./services/bdc-auto";
import {
  estTerminee,
  estStatutValidePourBdc,
  estTransitionVersValide,
  MissionData,
} from "./utils/mission";
import {
  estStatutPaye,
  notifierFacturePayee,
  notifierMissionAssignee,
  notifierNouvelleReservationHub,
  notifierSollicitationDispatch,
  scannerRappelsDepart1h,
} from "./notifications/push";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const CF_OPTS = {
  memory: "1GB" as const,
  timeoutSeconds: 120,
  serviceAccount: "kelegance@appspot.gserviceaccount.com",
};

/**
 * Dès qu'une mission est créée (réservation planifiée ou course instantanée) :
 * génère et envoie le bon de commande au client.
 */
export const onMissionCreee = functions
  .region("europe-west1")
  .runWith(CF_OPTS)
  .firestore.document("missions/{missionId}")
  .onCreate(async (snap, context) => {
    const missionId = context.params.missionId;
    const mission = snap.data() as MissionData | undefined;
    const missionRef = db.collection("missions").doc(missionId);

    if (!mission) {
      logger.warn("Mission créée sans données", { missionId });
      return;
    }

    if (mission.source === "hub_qr") {
      try {
        await notifierNouvelleReservationHub(missionId, mission as Record<string, unknown>);
        const envoi = await envoyerAlerteReservationHub(db, missionId, mission);
        await missionRef.update({
          notificationAdmin: "Réservation QR reçue",
          notificationAdminAt: admin.firestore.FieldValue.serverTimestamp(),
          alerteEmailAdmin: envoi.envoye,
          alerteEmailAdminMethode: envoi.methode,
        });
        logger.info("Réservation hub QR traitée", { missionId, email: envoi.envoye });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        logger.error("Échec traitement réservation hub", { missionId, message });
      }
      return;
    }

    if (mission.bdcGeneree === true) {
      logger.info("BDC déjà généré", { missionId });
      return;
    }

    if (!estStatutValidePourBdc(mission.statut)) {
      logger.info("BDC différé — réservation non validée", {
        missionId,
        statut: mission.statut,
      });
      return;
    }

    await traiterBonCommandeMission(missionId, mission);
  });

/**
 * Dès qu'une réservation est validée (statut → PLANIFIÉ / CONFIRMÉ / etc.) :
 * génère et envoie le bon de commande au client.
 */
export const onMissionValidee = functions
  .region("europe-west1")
  .runWith(CF_OPTS)
  .firestore.document("missions/{missionId}")
  .onUpdate(async (change, context) => {
    const missionId = context.params.missionId;
    const avant = change.before.data() as MissionData | undefined;
    const apres = change.after.data() as MissionData | undefined;

    if (!avant || !apres) return;
    if (apres.source === "hub_qr") return;
    if (!estTransitionVersValide(avant.statut, apres.statut)) return;

    logger.info("Réservation validée — déclenchement BDC", {
      missionId,
      statutAvant: avant.statut,
      statutApres: apres.statut,
    });

    await traiterBonCommandeMission(missionId, apres);
  });

/**
 * Dès qu'une mission passe à TERMINÉ :
 * génère et envoie la facture TTC au client.
 */
export const onMissionTerminee = functions
  .region("europe-west1")
  .runWith(CF_OPTS)
  .firestore.document("missions/{missionId}")
  .onUpdate(async (change, context) => {
    const missionId = context.params.missionId;
    const avant = change.before.data() as MissionData | undefined;
    const apres = change.after.data() as MissionData | undefined;
    const missionRef = db.collection("missions").doc(missionId);

    if (!avant || !apres) {
      logger.warn("Mission sans données avant/après", { missionId });
      return;
    }

    const etaitTerminee = estTerminee(avant.statut);
    const estMaintenantTerminee = estTerminee(apres.statut);

    if (etaitTerminee || !estMaintenantTerminee) {
      return;
    }

    if (apres.factureGeneree === true) {
      logger.info("Facture déjà générée", { missionId });
      return;
    }
    if (apres.factureGeneree === "processing" && !apres.factureErreur) {
      logger.info("Facture déjà en cours", { missionId });
      return;
    }

    try {
      const peutTraiter = await db.runTransaction(async (tx) => {
        const snap = await tx.get(missionRef);
        const data = snap.data() as MissionData | undefined;
        if (!data || data.factureGeneree === true) return false;
        if (data.factureGeneree === "processing" && !data.factureErreur) return false;
        tx.update(missionRef, {
          factureGeneree: "processing",
          factureErreur: admin.firestore.FieldValue.delete(),
          factureAutoDemarreeAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!peutTraiter) return;

      const emailClient = await resoudreEmailClient(db, apres);
      const dejaPubliee = await documentExisteDeja(db, missionId, "FACTURE TTC");
      const emailDejaEnvoye = apres.factureEmailEnvoye === true;

      if (dejaPubliee && emailDejaEnvoye) {
        logger.info("Facture déjà présente et e-mail déjà envoyé", { missionId });
        await missionRef.update({ factureGeneree: true, factureSource: "existant" });
        return;
      }

      const facture = dejaPubliee
        ? await chargerDocumentExistant(db, missionId, "FACTURE TTC")
        : await publierDocument(db, missionId, apres, "FACTURE TTC", emailClient);

      if (!facture) {
        throw new Error("Facture introuvable après publication");
      }

      const envoi = await envoyerFactureParEmail(db, facture);

      await missionRef.update({
        factureGeneree: true,
        factureToken: facture.token,
        factureLienWeb: facture.lienWeb,
        factureNumero: facture.numeroDocument,
        factureEmailEnvoye: envoi.envoye,
        factureEmailDestinataire: envoi.destinataire || null,
        factureEmailMethode: envoi.methode,
        factureEmailErreur: envoi.erreur ?? null,
        factureEmailEnvoyeAt: envoi.envoye
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
        notificationClient: envoi.envoye
          ? "Votre facture a été envoyée par e-mail."
          : "Votre facture est disponible dans l'application.",
        notificationClientAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("Facture automatique terminée", {
        missionId,
        factureToken: facture.token,
        emailEnvoye: envoi.envoye,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Échec génération facture automatique", { missionId, message, stack: err });
      try {
        await missionRef.update({
          factureGeneree: false,
          factureErreur: message,
          factureErreurAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (updateErr) {
        const updateMessage =
          updateErr instanceof Error ? updateErr.message : String(updateErr);
        logger.error("Impossible de marquer l'échec facture sur la mission", {
          missionId,
          updateMessage,
        });
      }
    }
  });

/**
 * Push FCM — nouvelle mission assignée à un chauffeur.
 */
export const onMissionAssigneePush = functions
  .region("europe-west1")
  .firestore.document("missions/{missionId}")
  .onWrite(async (change, context) => {
    const apres = change.after.exists ? (change.after.data() as MissionData | undefined) : undefined;
    if (!apres) return;

    const avant = change.before.exists ? (change.before.data() as MissionData | undefined) : undefined;
    const assigneApres = String(apres.chauffeurAssigne ?? "").trim();
    const assigneAvant = String(avant?.chauffeurAssigne ?? "").trim();

    if (!assigneApres || assigneApres === assigneAvant) return;

    const statut = String(apres.statut ?? "").toUpperCase();
    if (statut.includes("ANNUL") || statut.includes("TERMIN")) return;

    await notifierMissionAssignee(context.params.missionId, apres as Record<string, unknown>, assigneApres);
  });

/**
 * Push FCM — facture passée au statut Payée (Bras Droit).
 */
export const onFacturePayeePush = functions
  .region("europe-west1")
  .firestore.document("factures/{factureId}")
  .onUpdate(async (change, context) => {
    const avant = change.before.data() as Record<string, unknown> | undefined;
    const apres = change.after.data() as Record<string, unknown> | undefined;
    if (!avant || !apres) return;

    if (estStatutPaye(String(avant.statut ?? ""))) return;
    if (!estStatutPaye(String(apres.statut ?? ""))) return;

    await notifierFacturePayee(context.params.factureId, apres);
  });

/**
 * Push FCM — sollicitation dispatch Bras Droit → chauffeur.
 */
export const onSollicitationDispatchPush = functions
  .region("europe-west1")
  .firestore.document("presence/{chauffeurId}")
  .onUpdate(async (change, context) => {
    const avant = change.before.data() as Record<string, unknown> | undefined;
    const apres = change.after.data() as Record<string, unknown> | undefined;
    if (!avant || !apres) return;

    const solAvant = avant.sollicitationDispatch as Record<string, unknown> | undefined;
    const solApres = apres.sollicitationDispatch as Record<string, unknown> | undefined;
    if (!solApres || solApres.active !== true) return;

    const tsAvant =
      solAvant?.envoyeLe && typeof (solAvant.envoyeLe as { toMillis?: () => number }).toMillis === "function"
        ? (solAvant.envoyeLe as { toMillis: () => number }).toMillis()
        : null;
    const tsApres =
      solApres.envoyeLe && typeof (solApres.envoyeLe as { toMillis?: () => number }).toMillis === "function"
        ? (solApres.envoyeLe as { toMillis: () => number }).toMillis()
        : null;

    if (solAvant?.active === true && tsAvant != null && tsApres != null && tsAvant === tsApres) {
      return;
    }

    await notifierSollicitationDispatch(context.params.chauffeurId, solApres);
  });

/**
 * Rappels départ 1 h avant — scan planifié toutes les 15 min (Europe/Paris).
 * Complète les notifications locales planifiées côté app.
 */
export const rappelDepart1hPlanifie = functions
  .region("europe-west1")
  .pubsub.schedule("every 15 minutes")
  .timeZone("Europe/Paris")
  .onRun(async () => {
    const envoyes = await scannerRappelsDepart1h();
    logger.info("Rappels départ 1h", { envoyes });
    return null;
  });
