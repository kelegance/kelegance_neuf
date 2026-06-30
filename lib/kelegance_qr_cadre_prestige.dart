import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'kelegance_qr_codes.dart';

/// Charte visuelle partagée — QR codes Prestige.
abstract final class KeleganceQrTheme {
  static const Color fond = Color(0xFF0B1426);
  static const Color fondCarte = Color(0xFF121E33);
  static const Color or = Color(0xFFD4AF37);
  static const Color textePrincipal = Color(0xFFF5F0E6);
  static const Color texteDiscret = Color(0x99F5F0E6);
  static const double rayonBouton = 10.0;
}

/// Cadre Prestige — aperçu et export imprimable des QR codes.
class KeleganceQrCadrePrestige extends StatelessWidget {
  const KeleganceQrCadrePrestige({
    super.key,
    required this.type,
    this.compact = false,
  });

  final KeleganceQrType type;
  final bool compact;

  /// Payload unique — toujours [KeleganceQrCodes.donneesQr], jamais un lien externe.
  String get _payloadHub => KeleganceQrCodes.donneesQr(type);

  String get _sousTitre => switch (type) {
        KeleganceQrType.client => 'Hub Client',
        KeleganceQrType.brasDroit => 'Admin complet · APK / PWA',
        KeleganceQrType.collaborateur => 'Interface restreinte · APK / PWA',
      };

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 14.0 : 22.0;
    final qrSize = compact ? 200.0 : KeleganceQrCodes.tailleApercu;

    return Container(
      width: compact ? 280 : 320,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: KeleganceQrTheme.fond,
        borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton + 6),
        border: Border.all(color: KeleganceQrTheme.or.withOpacity(0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: KeleganceQrTheme.or.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'KELEGANCE PRESTIGE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KeleganceQrTheme.or,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w300,
              letterSpacing: compact ? 2.4 : 3.2,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
              border: Border.all(color: KeleganceQrTheme.or.withOpacity(0.25)),
            ),
            child: QrImageView(
              data: _payloadHub,
              size: qrSize,
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              errorCorrectionLevel: KeleganceQrCodes.niveauCorrectionErreur,
              gapless: false,
              eyeStyle: KeleganceQrCodes.styleYeux,
              dataModuleStyle: KeleganceQrCodes.styleModules,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            KeleganceQrCodes.libellePour(type).toUpperCase(),
            style: TextStyle(
              color: KeleganceQrTheme.or,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _sousTitre,
            style: TextStyle(
              color: KeleganceQrTheme.textePrincipal.withOpacity(0.65),
              fontSize: compact ? 9 : 10,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: KeleganceQrTheme.fondCarte,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KeleganceQrTheme.or.withOpacity(0.2)),
            ),
            child: Text(
              _payloadHub,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: KeleganceQrTheme.textePrincipal.withOpacity(0.8),
                fontSize: compact ? 9 : 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
