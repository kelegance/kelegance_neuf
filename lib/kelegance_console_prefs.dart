import 'package:shared_preferences/shared_preferences.dart';

/// Préférences persistées — console chauffeur (GPS, statuts).
abstract final class KeleganceConsolePrefs {
  static const String _kGpsAuto = 'kelegance_console_gps_auto_v1';
  static const String _kStatutAuto = 'kelegance_console_statut_auto_v1';
  static const String _kGpsDefaut = 'kelegance_console_gps_defaut_v1';

  static const String gpsGoogleMaps = 'Google Maps';
  static const String gpsWaze = 'Waze';
  static const String gpsAppleMaps = 'Apple Maps';

  static Future<({bool gpsAutomatique, bool statutAutomatique, String gpsDefaut})> charger() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      gpsAutomatique: prefs.getBool(_kGpsAuto) ?? true,
      statutAutomatique: prefs.getBool(_kStatutAuto) ?? false,
      gpsDefaut: prefs.getString(_kGpsDefaut) ?? gpsGoogleMaps,
    );
  }

  static Future<void> sauvegarder({
    bool? gpsAutomatique,
    bool? statutAutomatique,
    String? gpsDefaut,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (gpsAutomatique != null) await prefs.setBool(_kGpsAuto, gpsAutomatique);
    if (statutAutomatique != null) await prefs.setBool(_kStatutAuto, statutAutomatique);
    if (gpsDefaut != null) await prefs.setString(_kGpsDefaut, gpsDefaut);
  }
}
