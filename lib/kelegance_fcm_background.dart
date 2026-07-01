import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'kelegance_audio_alertes.dart';

/// Handler FCM arrière-plan (top-level requis) — son personnalisé même app fermée.
@pragma('vm:entry-point')
Future<void> keleganceFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);

  final type = message.data['type']?.toString() ?? '';
  if (kDebugMode) {
    debugPrint('Kelegance FCM background: ${message.notification?.title} type=$type');
  }

  if (!_estNouvelleCourse(type)) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(settings: const InitializationSettings(android: android));

  final androidImpl = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(
    AndroidNotificationChannel(
      KeleganceAudioAlertes.canalAndroidNouvelleCourse,
      'Nouvelles courses',
      description: 'Alerte sonore nouvelles courses',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse),
    ),
  );

  final notif = message.notification;
  await plugin.show(
    id: message.hashCode & 0x7FFFFFFF,
    title: notif?.title ?? 'Nouvelle course',
    body: notif?.body ?? 'Une course vous attend.',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        KeleganceAudioAlertes.canalAndroidNouvelleCourse,
        'Nouvelles courses',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(KeleganceAudioAlertes.rawAndroidNouvelleCourse),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: KeleganceAudioAlertes.sonIosNouvelleCourse,
      ),
    ),
  );
}

bool _estNouvelleCourse(String type) =>
    type == 'nouvelle_mission' || type == 'dispatch_sollicitation';
