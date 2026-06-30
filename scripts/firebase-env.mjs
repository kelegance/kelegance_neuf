/**
 * Prépare l'environnement Firebase CLI (Windows : contournement SSL proxy/antivirus).
 */
export function preparerEnvironnementFirebase() {
  if (process.platform === 'win32' && process.env.NODE_TLS_REJECT_UNAUTHORIZED !== '1') {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  }
}
