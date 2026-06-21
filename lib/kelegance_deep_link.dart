import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kelegance_web_urls.dart';

/// Liens d'entrée (QR code, SMS, e-mail) — réservation client ou console gestion.
abstract final class KeleganceDeepLink {
  static String get baseUrlReservation => KeleganceWebUrls.reserver;
  static String get baseUrlGestion => KeleganceWebUrls.gestion;

  static const String _prefsKeyReservation = 'kelegance_deep_link_reservation_v1';
  static const String _prefsKeyGestion = 'kelegance_deep_link_gestion_v1';
  static const MethodChannel _androidChannel =
      MethodChannel('com.example.kelegance_neuf/deeplink');

  static const Set<String> _segmentsReservation = {
    'reserver',
    'reservation',
    'book',
    'mappy',
  };

  static const Set<String> _segmentsGestion = {
    'gestion',
    'console',
    'chauffeur',
    'pro',
  };

  static bool estRouteReservation(Uri uri) {
    if (uri.queryParameters['action']?.toLowerCase() == 'reserver') {
      return true;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    return _segmentsReservation.contains(segments.first.toLowerCase());
  }

  static bool estRouteGestion(Uri uri) {
    if (uri.queryParameters['action']?.toLowerCase() == 'gestion') {
      return true;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    return _segmentsGestion.contains(segments.first.toLowerCase());
  }

  static Future<void> capturerLiensEntrants() async {
    await capturerDepuisUri(Uri.base);
    if (!kIsWeb) {
      await _capturerLienAndroid();
    }
  }

  static Future<void> capturerDepuisUri(Uri? uri) async {
    if (uri == null) return;
    if (estRouteReservation(uri)) {
      await enregistrerIntentReservation();
      if (kDebugMode) {
        debugPrint('Kelegance deep link — intent réservation : ${uri.toString()}');
      }
      return;
    }
    if (estRouteGestion(uri)) {
      await enregistrerIntentGestion();
      if (kDebugMode) {
        debugPrint('Kelegance deep link — intent gestion : ${uri.toString()}');
      }
    }
  }

  static Future<void> enregistrerIntentReservation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyReservation, true);
  }

  static Future<void> enregistrerIntentGestion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyGestion, true);
  }

  static Future<bool> aIntentReservationEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyReservation) ?? false;
  }

  static Future<bool> aIntentGestionEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyGestion) ?? false;
  }

  static Future<bool> consommerIntentReservation() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_prefsKeyReservation) ?? false;
    if (pending) {
      await prefs.remove(_prefsKeyReservation);
    }
    return pending;
  }

  static Future<bool> consommerIntentGestion() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_prefsKeyGestion) ?? false;
    if (pending) {
      await prefs.remove(_prefsKeyGestion);
    }
    return pending;
  }

  static Future<void> _capturerLienAndroid() async {
    try {
      final link = await _androidChannel.invokeMethod<String>('getInitialLink');
      if (link == null || link.isEmpty) return;
      await capturerDepuisUri(Uri.tryParse(link));
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance deep link Android: $e');
    }
  }
}
