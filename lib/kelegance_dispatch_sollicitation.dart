import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'kelegance_audio_alertes.dart';
import 'kelegance_firestore_live.dart';
import 'kelegance_presence_service.dart';
import 'kelegance_roles.dart';

/// Sollicitation dispatch Bras Droit → collaborateur en ligne (`presence` + notification).
abstract final class KeleganceDispatchSollicitation {
  static const String messageDefaut = 'Nouvelle demande de course, es-tu disponible ?';
  static const int _notificationId = 91042;

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _notificationsPretes = false;
  static String? _dernierHorodatageRecu;

  static Future<void> _initialiserNotifications() async {
    if (_notificationsPretes) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        KeleganceAudioAlertes.canalAndroidNouvelleCourse,
        'Nouvelles courses',
        description: 'Alerte sonore pour chaque nouvelle course ou sollicitation',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse),
      ),
    );
    await androidImpl?.requestNotificationsPermission();
    _notificationsPretes = true;
  }

  static bool estActive(Map<String, dynamic>? presence) {
    final raw = presence?['sollicitationDispatch'];
    if (raw is! Map) return false;
    return raw['active'] == true;
  }

  static Future<void> envoyer({
    required String chauffeurUid,
    String? chauffeurEmail,
  }) async {
    if (!KeleganceRoles.accesOutilsAdmin()) return;

    final admin = FirebaseAuth.instance.currentUser;
    if (admin != null && chauffeurUid == admin.uid) return;

    await KelegancePresenceService.collection.doc(chauffeurUid).set(
      {
        'sollicitationDispatch': {
          'active': true,
          'message': messageDefaut,
          'de': admin?.email?.toLowerCase().trim(),
          'envoyeLe': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> acquitter(String chauffeurUid) async {
    await KelegancePresenceService.collection.doc(chauffeurUid).set(
      {
        'sollicitationDispatch': {
          'active': false,
          'acquitteLe': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _afficherNotification(String corps) async {
    await _initialiserNotifications();
    unawaited(KeleganceAudioAlertes.playNotificationSound());
    await _plugin.show(
      id: _notificationId,
      title: 'KELEGANCE — Dispatch',
      body: corps,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          KeleganceAudioAlertes.canalAndroidNouvelleCourse,
          'Nouvelles courses',
          channelDescription: 'Sollicitations et nouvelles courses',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          sound: KeleganceAudioAlertes.sonIosNouvelleCourse,
        ),
      ),
    );
  }

  static String _cleHorodatageSollicitation(Map raw) {
    final envoyeLe = raw['envoyeLe'];
    if (envoyeLe is Timestamp) return envoyeLe.millisecondsSinceEpoch.toString();
    return envoyeLe?.toString() ?? '';
  }

  /// Écoute la sollicitation sur `presence/{uid}` du collaborateur connecté.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? demarrerEcoute(
    BuildContext context,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return KeleganceFirestoreLive.ecouterDocument(
      ref: FirebaseFirestore.instance
          .collection('presence')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(snap.data() ?? {}),
            toFirestore: (data, _) => data,
          )
          .doc(uid),
      etiquette: 'sollicitation',
      ignorerCacheSeul: true,
      onData: (snap) async {
        final data = snap.data();
        final raw = data?['sollicitationDispatch'];
        if (raw is! Map || raw['active'] != true) return;

        final horodatage = _cleHorodatageSollicitation(Map<String, dynamic>.from(raw));
        if (horodatage.isNotEmpty && horodatage == _dernierHorodatageRecu) return;
        _dernierHorodatageRecu = horodatage;

        final message = raw['message']?.toString() ?? messageDefaut;
        await _afficherNotification(message);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 6),
            content: Text(message),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () => unawaited(acquitter(uid)),
            ),
          ),
        );
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Kelegance dispatch écoute: $e');
      },
    );
  }
}
