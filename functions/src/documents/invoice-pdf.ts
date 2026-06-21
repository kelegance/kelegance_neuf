import chromium from "@sparticuz/chromium";
import puppeteer, { Browser } from "puppeteer-core";
import * as logger from "firebase-functions/logger";
import { genererHtmlDocument } from "./invoice-html";
import { DocumentDonnees } from "../utils/mission";

/** Génère un PDF fidèle au viewer web (même HTML + CSS, fond sombre inclus). */
export async function genererPdfDepuisHtml(html: string): Promise<Buffer> {
  let browser: Browser | null = null;
  try {
    browser = await lancerNavigateur();
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: "load" });
    const pdf = await page.pdf({
      format: "A4",
      printBackground: true,
      preferCSSPageSize: true,
      margin: { top: "0", right: "0", bottom: "0", left: "0" },
    });
    return Buffer.from(pdf);
  } finally {
    if (browser) {
      await browser.close().catch(() => undefined);
    }
  }
}

async function lancerNavigateur(): Promise<Browser> {
  const enCloud = Boolean(process.env.FUNCTION_TARGET || process.env.K_SERVICE);

  if (enCloud) {
    return puppeteer.launch({
      args: chromium.args,
      defaultViewport: { width: 794, height: 1123 },
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    });
  }

  const chromeLocal =
    process.env.PUPPETEER_EXECUTABLE_PATH ||
    (process.platform === "win32"
      ? "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
      : process.platform === "darwin"
        ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        : "/usr/bin/google-chrome");

  try {
    return puppeteer.launch({
      executablePath: chromeLocal,
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logger.warn("Chrome local introuvable, tentative Chromium embarqué", { message });
    return puppeteer.launch({
      args: chromium.args,
      defaultViewport: { width: 794, height: 1123 },
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    });
  }
}

/** Génère un PDF à partir du même HTML que le viewer web. */
export async function genererPdfDocument(type: string, donnees: DocumentDonnees): Promise<Buffer> {
  const html = genererHtmlDocument(type, donnees);
  return genererPdfDepuisHtml(html);
}

export function nomFichierPdf(type: string, numeroDocument: string): string {
  if (type === "FACTURE TTC") return `Kelegance-Facture-${numeroDocument}.pdf`;
  if (type === "BON DE COMMANDE RETOUR") return `Kelegance-BDC-Retour-${numeroDocument}.pdf`;
  return `Kelegance-BDC-${numeroDocument}.pdf`;
}
