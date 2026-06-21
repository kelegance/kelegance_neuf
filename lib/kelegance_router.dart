import 'package:flutter/foundation.dart';

import 'kelegance_web_urls.dart';

/// Routage web Kelegance (path URL strategy, sans go_router).
abstract final class KeleganceRouter {
  static const String accueil = '/';

  static String routeInitiale() {
    if (!kIsWeb) return accueil;
    final path = _normaliserChemin(Uri.base.path);
    if (path == KeleganceWebUrls.cheminAdminQr) {
      return KeleganceWebUrls.cheminAdminQr;
    }
    return accueil;
  }

  static String _normaliserChemin(String path) {
    if (path.isEmpty || path == '/') return accueil;
    return path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;
  }

  static String cheminDepuisSettings(String? name) {
    return _normaliserChemin(name ?? accueil);
  }
}
