import 'package:flutter/material.dart';

import 'kelegance_qr_cadre_prestige.dart';
import 'kelegance_roles.dart';
import 'kelegance_qr_codes.dart';
import 'kelegance_web_urls.dart';
import 'kelegance_qr_scanner_page.dart';
import 'qr_generator_page.dart';

/// Bouton admin — accès à la page de génération QR (paramètres chauffeur).
class KeleganceBoutonQrAdmin extends StatelessWidget {
  const KeleganceBoutonQrAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KeleganceRoles.notifierBrasDroit,
      builder: (context, _, __) {
        if (!KeleganceRoles.accesOutilsAdmin()) {
          return const SizedBox.shrink();
        }
        return _buildBouton(context);
      },
    );
  }

  Widget _buildBouton(BuildContext context) {
    const or = KeleganceQrTheme.or;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KeleganceQrTheme.fondCarte,
        borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton + 2),
        border: Border.all(color: or.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: or, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'QR CODES PRESTIGE',
                  style: TextStyle(
                    color: or,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'QR Collaborateur (interface restreinte) et Bras Droit (admin complet).',
            style: TextStyle(
              color: KeleganceQrTheme.textePrincipal.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Ouvrir le générateur', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: or,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton chauffeur collaborateur — lien de connexion + scanner QR.
class KeleganceBoutonQrChauffeur extends StatelessWidget {
  const KeleganceBoutonQrChauffeur({super.key});

  @override
  Widget build(BuildContext context) {
    const or = KeleganceQrTheme.or;
    final lien = KeleganceWebUrls.chauffeur;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KeleganceQrTheme.fondCarte,
        borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton + 2),
        border: Border.all(color: const Color(0xFF2E7D52).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: Color(0xFF2E7D52), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'QR & LIEN CHAUFFEUR',
                  style: TextStyle(
                    color: or,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Partagez votre lien de connexion ou scannez un QR mission.',
            style: TextStyle(
              color: KeleganceQrTheme.textePrincipal.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            lien,
            style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 10),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => KeleganceQrCodes.copierLien(context, KeleganceQrType.collaborateur),
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Copier le lien', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: or,
                    side: BorderSide(color: or.withOpacity(0.45)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KeleganceQrScannerPage()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scanner', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D52),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
