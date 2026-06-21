import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";
import nodemailer from "nodemailer";
import { KELEGANCE_IDENTITE } from "../constants";
import { DocumentPublie } from "../documents/invoice-service";
import { nomFichierPdf } from "../documents/invoice-pdf";

const smtpHost = defineString("SMTP_HOST", { default: "smtp.gmail.com" });
const smtpPort = defineString("SMTP_PORT", { default: "587" });
const smtpUser = defineString("SMTP_USER", { default: "admin@kelegance-prestige.com" });
const smtpPassword = defineString("SMTP_PASSWORD", { default: "" });
const smtpFrom = defineString("SMTP_FROM", {
  default: KELEGANCE_IDENTITE.emailAdmin,
});

export interface EnvoiDocumentsResultat {
  envoye: boolean;
  methode: "smtp" | "mail_collection" | "aucune";
  destinataire: string;
  erreur?: string;
}

function creerTransporteur() {
  const user = smtpUser.value();
  const pass = smtpPassword.value();
  if (!user || !pass) return null;

  return nodemailer.createTransport({
    host: smtpHost.value(),
    port: Number(smtpPort.value()),
    secure: Number(smtpPort.value()) === 465,
    auth: { user, pass },
  });
}

function pieceJointe(document: DocumentPublie) {
  return {
    filename: nomFichierPdf(document.type, document.numeroDocument),
    content: Buffer.from(document.pdfBase64, "base64"),
    contentType: "application/pdf",
  };
}

function corpsEmailBonCommande(document: DocumentPublie): string {
  const d = document.donnees;
  return `
    <div style="font-family:Segoe UI,Arial,sans-serif;color:#0B1426;max-width:560px;margin:0 auto">
      <h1 style="color:#D4AF37;font-weight:300;letter-spacing:2px">KELEGANCE PRESTIGE</h1>
      <p>Bonjour ${d.client},</p>
      <p>Votre réservation du <strong>${d.date}</strong> à <strong>${d.heure}</strong> est confirmée.</p>
      <p>Trajet : ${d.depart} → ${d.destination}</p>
      <p>Montant TTC : <strong>${d.prixTtc.toFixed(2)} €</strong></p>
      <p style="margin:24px 0">
        <a href="${document.lienWeb}" style="background:#D4AF37;color:#0B1426;padding:12px 20px;text-decoration:none;border-radius:6px;font-weight:600">
          Consulter le bon de commande
        </a>
      </p>
      <p style="font-size:12px;color:#666">Le PDF de votre bon de commande est joint à cet e-mail.</p>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
      <p style="font-size:11px;color:#888">${KELEGANCE_IDENTITE.exploitant} — ${KELEGANCE_IDENTITE.emailAdmin}</p>
    </div>`;
}

function corpsEmailFacture(document: DocumentPublie): string {
  const d = document.donnees;
  return `
    <div style="font-family:Segoe UI,Arial,sans-serif;color:#0B1426;max-width:560px;margin:0 auto">
      <h1 style="color:#D4AF37;font-weight:300;letter-spacing:2px">KELEGANCE PRESTIGE</h1>
      <p>Bonjour ${d.client},</p>
      <p>Votre course du <strong>${d.date}</strong> à <strong>${d.heure}</strong> est terminée.</p>
      <p>Trajet : ${d.depart} → ${d.destination}</p>
      <p>Montant TTC : <strong>${d.prixTtc.toFixed(2)} €</strong></p>
      <p style="margin:24px 0">
        <a href="${document.lienWeb}" style="background:#0B1426;color:#D4AF37;padding:12px 20px;text-decoration:none;border-radius:6px;font-weight:600;border:1px solid #D4AF37">
          Consulter la facture
        </a>
      </p>
      <p style="font-size:12px;color:#666">Le PDF de votre facture est joint à cet e-mail.</p>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
      <p style="font-size:11px;color:#888">${KELEGANCE_IDENTITE.exploitant} — ${KELEGANCE_IDENTITE.emailAdmin}</p>
    </div>`;
}

async function envoyerDocumentParEmail(
  db: admin.firestore.Firestore,
  document: DocumentPublie,
  options: { sujet: string; html: string; source: string },
): Promise<EnvoiDocumentsResultat> {
  const destinataire = document.emailClient;
  if (!destinataire) {
    return {
      envoye: false,
      methode: "aucune",
      destinataire: "",
      erreur: "Aucune adresse e-mail client trouvée",
    };
  }

  const attachment = pieceJointe(document);
  const transporteur = creerTransporteur();

  if (transporteur) {
    try {
      await transporteur.sendMail({
        from: smtpFrom.value(),
        to: destinataire,
        subject: options.sujet,
        html: options.html,
        attachments: [attachment],
      });
      logger.info("Document envoyé par SMTP", {
        destinataire,
        type: document.type,
        token: document.token,
      });
      return { envoye: true, methode: "smtp", destinataire };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("Échec envoi SMTP, repli sur collection mail", { message, type: document.type });
    }
  }

  try {
    await db.collection("mail").add({
      to: destinataire,
      message: {
        subject: options.sujet,
        html: options.html,
        attachments: [
          {
            filename: attachment.filename,
            content: (attachment.content as Buffer).toString("base64"),
            encoding: "base64",
          },
        ],
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: options.source,
    });
    logger.info("Document mis en file mail", { destinataire, type: document.type });
    return { envoye: true, methode: "mail_collection", destinataire };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error("Impossible d'enregistrer l'e-mail", { message, type: document.type });
    return { envoye: false, methode: "aucune", destinataire, erreur: message };
  }
}

/** Envoie le bon de commande seul (à la création de mission). */
export async function envoyerBonCommandeParEmail(
  db: admin.firestore.Firestore,
  bonCommande: DocumentPublie,
): Promise<EnvoiDocumentsResultat> {
  return envoyerDocumentParEmail(db, bonCommande, {
    sujet: `Kélégance Prestige — Bon de commande ${bonCommande.numeroDocument}`,
    html: corpsEmailBonCommande(bonCommande),
    source: "cloud_function_bdc_auto",
  });
}

/** Envoie la facture seule (à la fin de course). */
export async function envoyerFactureParEmail(
  db: admin.firestore.Firestore,
  facture: DocumentPublie,
): Promise<EnvoiDocumentsResultat> {
  return envoyerDocumentParEmail(db, facture, {
    sujet: `Kélégance Prestige — Facture ${facture.numeroDocument}`,
    html: corpsEmailFacture(facture),
    source: "cloud_function_facture_auto",
  });
}
