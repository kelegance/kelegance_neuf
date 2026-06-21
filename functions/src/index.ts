import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import { envoyerBonCommandeParEmail, envoyerFactureParEmail } from "./email/mailer";
import {
  chargerDocumentExistant,
  documentExisteDeja,
  DocumentPublie,
  publierDocument,
  resoudreEmailClient,
} from "./documents/invoice-service";
import { genererPdfDepuisHtml, genererPdfDocument } from "./documents/invoice-pdf";
import {
  estTerminee,
  MissionData,
  typeBonCommandeMission,
} from "./utils/mission";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const CF_OPTS = {
  memory: "1GB" as const,
  timeoutSeconds: 120,
  serviceAccount: "kelegance@appspot.gserviceaccount.com",
};

async function assurerPdf(document: DocumentPublie) {
  if (document.pdfBase64) return;
  const pdfBuffer = document.htmlContenu
    ? await genererPdfDepuisHtml(document.htmlContenu)
    : await genererPdfDocument(document.type, document.donnees);
  document.pdfBase64 = pdfBuffer.toString("base64");
}

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

    if (mission.bdcGeneree === true) {
      logger.info("BDC déjà généré", { missionId });
      return;
    }
    if (mission.bdcGeneree === "processing" && !mission.bdcErreur) {
      logger.info("BDC déjà en cours", { missionId });
      return;
    }

    const typeBdc = typeBonCommandeMission(mission);

    try {
      const peutTraiter = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(missionRef);
        const data = fresh.data() as MissionData | undefined;
        if (!data || data.bdcGeneree === true) return false;
        if (data.bdcGeneree === "processing" && !data.bdcErreur) return false;
        tx.update(missionRef, {
          bdcGeneree: "processing",
          bdcErreur: admin.firestore.FieldValue.delete(),
          bdcAutoDemarreAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!peutTraiter) return;

      const emailClient = await resoudreEmailClient(db, mission);
      const dejaPublie = await documentExisteDeja(db, missionId, typeBdc);

      const bonCommande = dejaPublie
        ? await chargerDocumentExistant(db, missionId, typeBdc)
        : await publierDocument(db, missionId, mission, typeBdc, emailClient);

      if (!bonCommande) {
        throw new Error("Bon de commande introuvable après publication");
      }

      await assurerPdf(bonCommande);

      const envoi = await envoyerBonCommandeParEmail(db, bonCommande);

      await missionRef.update({
        bdcGeneree: true,
        bdcToken: bonCommande.token,
        bdcLienWeb: bonCommande.lienWeb,
        bdcNumero: bonCommande.numeroDocument,
        bdcType: typeBdc,
        bdcEmailEnvoye: envoi.envoye,
        bdcEmailDestinataire: envoi.destinataire || null,
        bdcEmailMethode: envoi.methode,
        bdcEmailErreur: envoi.erreur ?? null,
        bdcEmailEnvoyeAt: envoi.envoye
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
        notificationClient: envoi.envoye
          ? "Votre bon de commande a été envoyé par e-mail."
          : "Votre bon de commande est disponible dans l'application.",
        notificationClientAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("BDC automatique terminé", {
        missionId,
        bdcToken: bonCommande.token,
        emailEnvoye: envoi.envoye,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Échec génération BDC automatique", { missionId, message, stack: err });
      try {
        await missionRef.update({
          bdcGeneree: false,
          bdcErreur: message,
          bdcErreurAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (updateErr) {
        const updateMessage =
          updateErr instanceof Error ? updateErr.message : String(updateErr);
        logger.error("Impossible de marquer l'échec BDC sur la mission", {
          missionId,
          updateMessage,
        });
      }
    }
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

      await assurerPdf(facture);

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
