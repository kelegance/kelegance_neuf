import 'package:flutter/material.dart';

import 'kelegance_qr_codes.dart';
import 'qr_generator_page.dart';

/// Bouton admin — accès à la page de génération QR (paramètres chauffeur).
class KeleganceBoutonQrAdmin extends StatelessWidget {
  const KeleganceBoutonQrAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    if (!KeleganceQrCodes.utilisateurEstAdmin()) {
      return const SizedBox.shrink();
    }

    const or = Color(0xFFD4AF37);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
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
            'Générez les codes Client (/reserver) et Bras Droit (/gestion).',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
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
            ),
          ),
        ],
      ),
    );
  }
}
