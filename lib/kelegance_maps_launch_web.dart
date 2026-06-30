import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

/// Appel synchrone depuis le geste utilisateur — évite le pop-up « ouvrir l'application ».
void ouvrirMapsNativeWeb(String adresse) {
  if (!kIsWeb) return;
  final query = adresse.trim();
  if (query.isEmpty) return;

  try {
    js_util.callMethod(js_util.globalThis, 'keleganceOpenMapsNative', [query]);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Kelegance maps web native: $e');
    }
  }
}
