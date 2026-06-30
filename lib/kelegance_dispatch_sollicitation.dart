import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'kelegance_roles.dart';

/// Sollicitation dispatch Bras Droit → collaborateur en ligne (Firestore + notification locale).
abstract final class KeleganceDispatchSollicitation {
  static const String messageDefaut = 'Nouvelle demande de course, es-tu disponible ?';
  static const String _channelId = 'kelegance_dispatch';
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

    const channel = AndroidNotificationChannel(
      _channelId,
      'Dispatch Kelegance',
      description: 'Sollicitations de course des Bras Droit',
      importance: Importance.high,
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
    await androidImpl?.requestNotificationsPermission();

    _notificationsPretes = true;
  }

  static bool estActive(Map<String, dynamic>? chauffeur) {
    final raw = chauffeur?['sollicitationDispatch'];
    if (raw is! Map) return false;
    return raw['active'] == true;
  }

  static Future<void> envoyer({
    required String chauffeurUid,
    String? chauffeurEmail,
  }) async {
    if (!KeleganceRoles.accesOutilsAdmin()) return;
    final mail = chauffeurEmail?.toLowerCase().trim();
    if (mail != null && KeleganceRoles.estBrasDroit(mail)) return;

    final admin = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('chauffeurs').doc(chauffeurUid).set(
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
    await FirebaseFirestore.instance.collection('chauffeurs').doc(chauffeurUid).set(
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
    await _plugin.show(
      id: _notificationId,
      title: 'KELEGANCE — Dispatch',
      body: corps,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Dispatch Kelegance',
          channelDescription: 'Sollicitations de course',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Écoute la sollicitation sur le document chauffeur du collaborateur connecté.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? demarrerEcoute(
    BuildContext context,
  ) {
    if (KeleganceRoles.estBrasDroit()) return null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance.collection('chauffeurs').doc(uid).snapshots().listen(
      (snap) async {
        final data = snap.data();
        final raw = data?['sollicitationDispatch'];
        if (raw is! Map || raw['active'] != true) return;

        final horodatage = raw['envoyeLe']?.toString() ?? '';
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
