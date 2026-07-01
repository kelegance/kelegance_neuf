import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'kelegance_audio_alertes.dart';
import 'kelegance_factures_service.dart';
import 'kelegance_missions_service.dart';
import 'kelegance_notification_prefs.dart';
import 'kelegance_roles.dart';

/// Notifications proactives — FCM + écoute Firestore + rappels locaux 1 h avant départ.
abstract final class KeleganceNotificationService {
  static const String fuseauParis = 'Europe/Paris';
  static const String _prefsRappels = 'kelegance_rappels_depart_1h_v1';
  static const String _channelProactif = 'kelegance_proactif';
  static const String _channelRappel = 'kelegance_rappel_depart';
  static const String _channelNouvelleCourse = KeleganceAudioAlertes.canalAndroidNouvelleCourse;

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final Map<String, String> _dernierChauffeurAssigne = {};
  static final Set<String> _facturesPayeesVues = {};

  static bool _pret = false;
  static bool _initialSyncMissions = true;
  static bool _initialSyncFactures = true;
  static StreamSubscription<KeleganceMissionsSnapshot>? _subMissions;
  static StreamSubscription<KeleganceFacturesSnapshot>? _subFactures;
  static StreamSubscription<String>? _subTokenRefresh;
  static String? _emailSession;
  static String? _uidSession;

  static Future<void> initialiser() async {
    if (_pret || kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final tzLocale = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzLocale.identifier));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation(fuseauParis));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(settings: const InitializationSettings(android: android, iOS: ios));

    final androidImpl = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelProactif,
        'Alertes Kelegance',
        description: 'Nouvelles missions et factures payées',
        importance: Importance.high,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelRappel,
        'Rappels de départ',
        description: 'Rappel 1 h avant chaque transfert planifié',
        importance: Importance.high,
      ),
    );
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelNouvelleCourse,
        'Nouvelles courses',
        description: 'Alerte sonore dédiée aux nouvelles courses assignées',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse),
      ),
    );
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_traiterMessageFcmPremierPlan);
    _subTokenRefresh ??= messaging.onTokenRefresh.listen((token) {
      unawaited(_persisterToken(token));
    });

    _pret = true;
    if (kDebugMode) debugPrint('KeleganceNotificationService initialisé');
  }

  static Future<void> demarrerPourUtilisateur(User user) async {
    if (kIsWeb) return;
    await initialiser();

    _emailSession = user.email?.trim().toLowerCase();
    _uidSession = user.uid;
    _initialSyncMissions = true;
    _initialSyncFactures = true;
    _dernierChauffeurAssigne.clear();
    _facturesPayeesVues.clear();

    await KeleganceNotificationPrefs.charger();
    await _persisterToken(await FirebaseMessaging.instance.getToken());

    await arreterEcoute();
    KeleganceMissionsService.demarrer();
    _subMissions = KeleganceMissionsService.flux.listen(
      (snap) => unawaited(_traiterMissions(snap)),
      onError: (e) {
        if (kDebugMode) debugPrint('KeleganceNotificationService missions: $e');
      },
    );

    _subFactures = KeleganceFacturesService.flux.listen(
      (snap) => unawaited(_traiterFactures(snap)),
      onError: (e) {
        if (kDebugMode) debugPrint('KeleganceNotificationService factures: $e');
      },
    );

    if (kDebugMode) debugPrint('KeleganceNotificationService — écoute active');
  }

  static Future<void> arreter() async {
    await arreterEcoute();
    await supprimerToken();
    _dernierChauffeurAssigne.clear();
    _facturesPayeesVues.clear();
    _emailSession = null;
    _uidSession = null;
  }

  static Future<void> arreterEcoute() async {
    await _subMissions?.cancel();
    await _subFactures?.cancel();
    _subMissions = null;
    _subFactures = null;
  }

  static Future<void> supprimerToken() async {
    if (kIsWeb) return;
    final uid = _uidSession ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
        'fcm_token': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(uid).set({
        'fcmToken': FieldValue.delete(),
        'fcm_token': FieldValue.delete(),
      }, SetOptions(merge: true));
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceNotificationService supprimerToken: $e');
    }
  }

  static Future<void> _persisterToken(String? token) async {
    if (kIsWeb || token == null || token.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await KeleganceNotificationPrefs.charger();
    final payload = <String, dynamic>{
      'fcmToken': token,
      'fcm_token': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'fcmPlatform': defaultTargetPlatform.name,
      'notificationPrefs': {
        'nouvelleMission': prefs.nouvelleMission,
        'rappelDepart1h': prefs.rappelDepart1h,
        'facturePayee': prefs.facturePayee,
      },
    };

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(payload, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceNotificationService token: $e');
    }
  }

  static void _traiterMessageFcmPremierPlan(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    final notif = message.notification;
    if (notif == null) return;

    final canal = _canalPourType(type);
    if (_estNouvelleCourse(type)) {
      unawaited(KeleganceAudioAlertes.playNotificationSound());
    }

    unawaited(
      _afficherLocale(
        titre: notif.title ?? 'Kelegance',
        corps: notif.body ?? '',
        canal: canal,
        id: message.hashCode & 0x7FFFFFFF,
        payload: type,
        nouvelleCourse: _estNouvelleCourse(type),
      ),
    );
  }

  static bool _estNouvelleCourse(String type) =>
      type == 'nouvelle_mission' || type == 'dispatch_sollicitation';

  static String _canalPourType(String type) =>
      _estNouvelleCourse(type) ? _channelNouvelleCourse : _channelProactif;

  static Future<void> _traiterMissions(KeleganceMissionsSnapshot snap) async {
    final prefs = await KeleganceNotificationPrefs.charger();

    if (snap.premierChargement && _initialSyncMissions) {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _dernierChauffeurAssigne[doc.id] = (data['chauffeurAssigne']?.toString() ?? '').trim();
      }
      _initialSyncMissions = false;
      if (prefs.rappelDepart1h) {
        await synchroniserRappelsDepart(snap.docs);
      }
      return;
    }
    _initialSyncMissions = false;

    for (final change in snap.changes) {
      final data = change.doc.data() as Map<String, dynamic>;
      if (!KeleganceRoles.peutVoirMission(data, email: _emailSession)) continue;

      final assigne = (data['chauffeurAssigne']?.toString() ?? '').trim();
      final avant = _dernierChauffeurAssigne[change.doc.id] ?? '';
      _dernierChauffeurAssigne[change.doc.id] = assigne;

      if (!prefs.nouvelleMission) continue;
      if (!_estNouvelleAssignation(change.type, assigne, avant, data)) continue;

      final lieu = _libelleLieuMission(data);
      unawaited(KeleganceAudioAlertes.playNotificationSound());
      await _afficherLocale(
        titre: 'Nouvelle mission',
        corps: lieu.isEmpty ? 'Une course vous a été assignée.' : 'Course assignée : $lieu',
        canal: _channelNouvelleCourse,
        id: change.doc.id.hashCode & 0x7FFFFFFF,
        payload: 'mission:${change.doc.id}',
        nouvelleCourse: true,
      );
    }

    if (prefs.rappelDepart1h) {
      await synchroniserRappelsDepart(snap.docs);
    }
  }

  static bool _estNouvelleAssignation(
    DocumentChangeType type,
    String assigne,
    String avant,
    Map<String, dynamic> data,
  ) {
    final statut = (data['statut']?.toString() ?? '').toUpperCase();
    if (statut.contains('ANNUL') || statut.contains('TERMIN')) return false;
    if (assigne.isEmpty) return false;

    if (type == DocumentChangeType.added) return true;
    if (type == DocumentChangeType.modified) return assigne != avant;
    return false;
  }

  static Future<void> _traiterFactures(KeleganceFacturesSnapshot snap) async {
    if (!KeleganceRoles.estBrasDroit(_emailSession)) return;
    final prefs = await KeleganceNotificationPrefs.charger();
    if (!prefs.facturePayee) return;

    if (snap.premierChargement && _initialSyncFactures) {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final statut = KeleganceFacturesService.presenterStatut(data['statut']?.toString());
        if (statut.libelle == 'Payée') _facturesPayeesVues.add(doc.id);
      }
      _initialSyncFactures = false;
      return;
    }
    _initialSyncFactures = false;

    for (final change in snap.changes) {
      if (change.type != DocumentChangeType.modified) continue;
      final data = change.doc.data() as Map<String, dynamic>;
      final statut = KeleganceFacturesService.presenterStatut(data['statut']?.toString());
      if (statut.libelle != 'Payée') continue;
      if (_facturesPayeesVues.contains(change.doc.id)) continue;
      _facturesPayeesVues.add(change.doc.id);

      final numero = data['numero']?.toString() ?? change.doc.id;
      final montant = KeleganceFacturesService.parserMontant(data['montant']);
      await _afficherLocale(
        titre: 'Facture payée',
        corps: 'Facture $numero — ${montant.toStringAsFixed(2)} €',
        canal: _channelProactif,
        id: ('facture_${change.doc.id}').hashCode & 0x7FFFFFFF,
        payload: 'facture:${change.doc.id}',
      );
    }
  }

  static String _libelleLieuMission(Map<String, dynamic> data) {
    final parts = <String>[
      data['depart']?.toString() ?? data['lieu_depart']?.toString() ?? '',
      data['destination']?.toString() ?? data['lieu_arrivee']?.toString() ?? '',
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' → ');
  }

  static DateTime? _extraireHorodatageMission(Map<String, dynamic> data) {
    final dateRaw = data['date']?.toString().trim() ?? '';
    final heureRaw = data['heure']?.toString().trim() ?? data['heure_depart']?.toString().trim() ?? '';
    if (dateRaw.isEmpty) return null;

    DateTime? datePart;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(dateRaw);
    if (iso != null) {
      datePart = DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(dateRaw);
    if (datePart == null && slash != null) {
      datePart = DateTime(int.parse(slash.group(3)!), int.parse(slash.group(2)!), int.parse(slash.group(1)!));
    }
    datePart ??= DateTime.tryParse(dateRaw.split(' ').first);
    if (datePart == null) return null;

    var h = 0;
    var m = 0;
    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(heureRaw);
    if (hm != null) {
      h = int.parse(hm.group(1)!);
      m = int.parse(hm.group(2)!);
    }
    return DateTime(datePart.year, datePart.month, datePart.day, h, m);
  }

  static bool _statutEligibleRappel(String? statut) {
    final s = (statut ?? '').toUpperCase();
    if (s.contains('ANNUL') || s.contains('TERMIN')) return false;
    return s.contains('PLAN') ||
        s.contains('CONFIRM') ||
        s == 'ACCEPTEE' ||
        s.contains('ATTENTE') ||
        s == 'REDISPATCHÉ' ||
        s == 'REDISPATCHE';
  }

  static int _idRappel(String missionId) => ('rappel1h_$missionId').hashCode & 0x7FFFFFFF;

  static Future<void> synchroniserRappelsDepart(Iterable<QueryDocumentSnapshot> docs) async {
    if (kIsWeb) return;
    await initialiser();

    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_prefsRappels) ?? '{}';
    Map<String, dynamic> planifies;
    try {
      planifies = jsonDecode(brut) as Map<String, dynamic>;
    } catch (_) {
      planifies = {};
    }

    final idsActifs = <String>{};
    final paris = tz.getLocation(fuseauParis);
    final maintenant = tz.TZDateTime.now(paris);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!KeleganceRoles.peutVoirMission(data, email: _emailSession)) continue;
      if (!_statutEligibleRappel(data['statut']?.toString())) {
        await _annulerRappel(doc.id, planifies);
        continue;
      }

      final rdv = _extraireHorodatageMission(data);
      if (rdv == null) continue;

      final rappel = tz.TZDateTime.from(rdv.subtract(const Duration(hours: 1)), paris);
      if (!rappel.isAfter(maintenant)) {
        await _annulerRappel(doc.id, planifies);
        continue;
      }

      idsActifs.add(doc.id);
      final signature = '${rdv.toIso8601String()}|${data['statut']}';
      if (planifies[doc.id] == signature) continue;

      final lieu = _libelleLieuMission(data);
      final heure = data['heure']?.toString() ?? data['heure_depart']?.toString() ?? '';
      await _local.zonedSchedule(
        id: _idRappel(doc.id),
        title: 'Départ dans 1 h',
        body: lieu.isEmpty ? 'Transfert planifié à $heure' : '$lieu — départ à $heure',
        scheduledDate: rappel,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelRappel,
            'Rappels de départ',
            channelDescription: 'Rappel 1 h avant chaque transfert planifié',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'rappel:${doc.id}',
      );
      planifies[doc.id] = signature;
    }

    final aSupprimer = planifies.keys.where((id) => !idsActifs.contains(id)).toList();
    for (final id in aSupprimer) {
      await _annulerRappel(id, planifies);
    }

    await prefs.setString(_prefsRappels, jsonEncode(planifies));
  }

  static Future<void> _annulerRappel(String missionId, Map<String, dynamic> planifies) async {
    await _local.cancel(id: _idRappel(missionId));
    planifies.remove(missionId);
  }

  static Future<void> _afficherLocale({
    required String titre,
    required String corps,
    required String canal,
    required int id,
    String? payload,
    bool nouvelleCourse = false,
  }) async {
    if (kIsWeb) return;
    await initialiser();
    await _local.show(
      id: id,
      title: titre,
      body: corps,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal,
          nouvelleCourse ? 'Nouvelles courses' : (canal == _channelRappel ? 'Rappels de départ' : 'Alertes Kelegance'),
          importance: nouvelleCourse ? Importance.max : Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: nouvelleCourse
              ? const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          sound: nouvelleCourse ? KeleganceAudioAlertes.sonIosNouvelleCourse : null,
        ),
      ),
    );
  }
}
