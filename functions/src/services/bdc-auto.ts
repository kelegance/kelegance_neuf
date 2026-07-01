import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { envoyerBonCommandeParEmail } from "../email/mailer";
import {
  chargerDocumentExistant,
  documentExisteDeja,
  publierDocument,
  resoudreEmailClient,
} from "../documents/invoice-service";
import { MissionData, typeBonCommandeMission } from "../utils/mission";
import { ChauffeurDonneesIncompletesError } from "./chauffeurs-referentiel";

function db() {
  return admin.firestore();
}

/**
 * Génère le bon de commande (template HTML) et l'envoie par e-mail au client.
 * Idempotent via transaction `bdcGeneree`.
 */
export async function traiterBonCommandeMission(
  missionId: string,
  mission: MissionData,
): Promise<void> {
  const missionRef = db().collection("missions").doc(missionId);

  if (mission.bdcGeneree === true) {
    logger.info("BDC déjà généré", { missionId });
    return;
  }
  if (mission.bdcGeneree === "processing" && !mission.bdcErreur) {
    logger.info("BDC déjà en cours", { missionId });
    return;
  }

  const typeBdc = typeBonCommandeMission(mission);

  const peutTraiter = await db().runTransaction(async (tx) => {
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

  try {
    const emailClient = await resoudreEmailClient(db(), mission);
    const dejaPublie = await documentExisteDeja(db(), missionId, typeBdc);

    const bonCommande = dejaPublie
      ? await chargerDocumentExistant(db(), missionId, typeBdc)
      : await publierDocument(db(), missionId, mission, typeBdc, emailClient);

    if (!bonCommande) {
      throw new Error("Bon de commande introuvable après publication");
    }

    const envoi = await envoyerBonCommandeParEmail(db(), bonCommande);

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
    const message =
      err instanceof ChauffeurDonneesIncompletesError
        ? err.message
        : err instanceof Error
          ? err.message
          : String(err);
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
}
