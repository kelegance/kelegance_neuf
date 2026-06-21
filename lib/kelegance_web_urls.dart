import 'package:flutter/foundation.dart';

/// URLs publiques Kelegance (Netlify / Firebase Hosting).
abstract final class KeleganceWebUrls {
  /// Domaine de production — surcharge possible via `--dart-define=KELEGANCE_WEB_ORIGIN=https://votre-domaine.netlify.app`.
  static const String domaineProduction = String.fromEnvironment(
    'KELEGANCE_WEB_ORIGIN',
    defaultValue: 'https://cheerful-salamander-565dfc.netlify.app',
  );

  static const String cheminReserver = '/reserver';
  static const String cheminGestion = '/gestion';
  static const String cheminAdminQr = '/admin/qrcodes';

  /// Origine utilisée pour les QR imprimés : domaine courant en prod web, sinon constante.
  static String get origine {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && !host.startsWith('127.')) {
        return Uri.base.origin;
      }
    }
    return domaineProduction;
  }

  static String get reserver => '$origine$cheminReserver';
  static String get gestion => '$origine$cheminGestion';
  static String get adminQrCodes => '$origine$cheminAdminQr';
}
