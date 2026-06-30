import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kelegance_missions_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Handler arrière-plan (top-level requis par flutter_local_notifications).
@pragma('vm:entry-point')
void keleganceReveilNotificationTapBackground(NotificationResponse response) {
  KeleganceReveilMissions.onNotificationTapped(response);
}

/// Alertes réveil 5h00 (Europe/Paris) — courses planifiées v2.1.2.
///
/// Service **isolé** de l'UI console : planification OS via [zonedSchedule],
/// sans `showDialog`, sans `Navigator`, sans dépendance au Stack guidage.
abstract final class KeleganceReveilMissions {
  static const String fuseauParis = 'Europe/Paris';
  static const String _prefsKey = 'kelegance_reveils_planifies_v212';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;
  static StreamSubscription<KeleganceMissionsSnapshot>? _abonnementMissions;

  /// Écoute le flux missions partagé — indépendante du cycle de vie de [PageConsole] / Stack UI.
  static Future<void> demarrerSynchronisationFirestore() async {
    if (_abonnementMissions != null) return;
    await initialiser();
    KeleganceMissionsService.demarrer();
    _abonnementMissions = KeleganceMissionsService.flux.listen(
      (snapshot) => unawaited(synchroniserDepuisMissions(snapshot.docs)),
      onError: (e) {
        if (kDebugMode) debugPrint('Kelegance sync réveils 5h: $e');
      },
    );
    if (kDebugMode) {
      debugPrint('Kelegance Réveil 5h — écoute live missions active');
    }
  }

  static Future<void> arreterSynchronisationFirestore() async {
    await _abonnementMissions?.cancel();
    _abonnementMissions = null;
  }

  /// Tap sur notification réveil — son/vibration système seulement, pas d'UI in-app.
  static void onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint(
        'Kelegance Réveil 5h — notification [${response.payload}] '
        '(aucune navigation externe, aucune modale)',
      );
    }
  }

  static Future<void> initialiser() async {
    if (_pret) return;

    tz_data.initializeTimeZones();
    try {
      final tzLocale = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzLocale.identifier));
    } catch (e) {
      debugPrint('Kelegance Réveil timezone locale: $e — repli Europe/Paris');
      tz.setLocalLocation(tz.getLocation(fuseauParis));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      // Réveil 5h : notification système uniquement — jamais de navigation ni modale UI.
      onDidReceiveNotificationResponse: onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: keleganceReveilNotificationTapBackground,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _pret = true;
    debugPrint('Kelegance Réveil 5h initialisé (fuseau planification: $fuseauParis)');
  }

  /// 05:00:00 le jour J, fuseau Europe/Paris (règle stricte v2.1.2).
  static tz.TZDateTime reveil5hPourJour(DateTime jour) {
    final paris = tz.getLocation(fuseauParis);
    return tz.TZDateTime(paris, jour.year, jour.month, jour.day, 5, 0, 0);
  }

  static DateTime? parserDateMission(String? raw) {
    if (raw == null) return null;
    final texte = raw.trim();
    if (texte.isEmpty) return null;

    final formatFr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final matchFr = formatFr.firstMatch(texte);
    if (matchFr != null) {
      final jour = int.parse(matchFr.group(1)!);
      final mois = int.parse(matchFr.group(2)!);
      final annee = int.parse(matchFr.group(3)!);
      return DateTime(annee, mois, jour);
    }

    try {
      final parsed = DateTime.parse(texte);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  static bool statutEligibleReveil(String? statut) {
    final s = (statut ?? '').toUpperCase();
    if (s.contains('ANNUL') || s.contains('TERMIN')) return false;
    return s.contains('PLAN') ||
        s.contains('CONFIRM') ||
        s == 'ACCEPTEE' ||
        s.contains('ATTENTE') ||
        s == 'REDISPATCHÉ' ||
        s == 'REDISPATCHE';
  }

  static int _notificationId(String missionId) => missionId.hashCode & 0x7FFFFFFF;

  static Future<void> planifierPourMission({
    required String missionId,
    required Map<String, dynamic> data,
  }) async {
    await initialiser();

    if (!statutEligibleReveil(data['statut']?.toString())) {
      await annulerPourMission(missionId);
      return;
    }

    final dateRdv = parserDateMission(data['date']?.toString());
    if (dateRdv == null) {
      debugPrint('Kelegance Réveil: date illisible pour $missionId (${data['date']})');
      return;
    }

    final paris = tz.getLocation(fuseauParis);
    final reveil = reveil5hPourJour(dateRdv);
    final maintenant = tz.TZDateTime.now(paris);
    if (!reveil.isAfter(maintenant)) {
      debugPrint('Kelegance Réveil: 5h déjà passée pour $missionId (${dateRdv.toIso8601String().split('T').first})');
      await annulerPourMission(missionId);
      return;
    }

    final heure = data['heure_depart']?.toString() ?? data['heure']?.toString() ?? '';
    final client = data['client_nom']?.toString() ?? 'Client';
    final destination = data['destination']?.toString() ?? '';

    try {
      await _plugin.zonedSchedule(
        id: _notificationId(missionId),
        title: 'Kelegance — Course du jour',
        body: 'Réveil 5h : $client${heure.isNotEmpty ? ' à $heure' : ''}${destination.isNotEmpty ? ' → $destination' : ''}',
        scheduledDate: reveil,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'kelegance_reveil_5h',
            'Alertes réveil 5h',
            channelDescription: 'Rappel impératif à 5h00 le jour de la course planifiée',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: missionId,
      );

      await _enregistrerMissionPlanifiee(missionId, reveil.millisecondsSinceEpoch);
      debugPrint('Kelegance Réveil planifié [$missionId] → $reveil ($fuseauParis)');
    } catch (e) {
      debugPrint('Kelegance Réveil erreur planification [$missionId]: $e');
    }
  }

  static Future<void> annulerPourMission(String missionId) async {
    await initialiser();
    try {
      await _plugin.cancel(id: _notificationId(missionId));
      await _retirerMissionPlanifiee(missionId);
    } catch (e) {
      debugPrint('Kelegance Réveil annulation [$missionId]: $e');
    }
  }

  static Future<void> synchroniserDepuisMissions(Iterable<QueryDocumentSnapshot> docs) async {
    await initialiser();
    final idsActifs = <String>{};

    for (final doc in docs) {
      final data = doc.data();
      if (data is! Map<String, dynamic>) continue;
      if (!statutEligibleReveil(data['statut']?.toString())) {
        await annulerPourMission(doc.id);
        continue;
      }
      idsActifs.add(doc.id);
      await planifierPourMission(missionId: doc.id, data: data);
    }

    final prefs = await SharedPreferences.getInstance();
    final enc = prefs.getString(_prefsKey);
    if (enc != null) {
      final anciens = (jsonDecode(enc) as Map<String, dynamic>).keys.cast<String>();
      for (final id in anciens) {
        if (!idsActifs.contains(id)) {
          await annulerPourMission(id);
        }
      }
    }
  }

  static Future<void> _enregistrerMissionPlanifiee(String missionId, int epochMs) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _lireMap(prefs);
    map[missionId] = epochMs;
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  static Future<void> _retirerMissionPlanifiee(String missionId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _lireMap(prefs);
    map.remove(missionId);
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  static Map<String, dynamic> _lireMap(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
