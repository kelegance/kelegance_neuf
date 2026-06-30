import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Handler FCM arrière-plan (top-level requis).
@pragma('vm:entry-point')
Future<void> keleganceFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  if (kDebugMode) {
    debugPrint('Kelegance FCM background: ${message.notification?.title}');
  }
}
