import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:kelegance_neuf/kelegance_init_firestore.dart';

/// Script d'injection unique — liste officielle v2.4.3.
/// Exécution : flutter run -t lib/inject_official_users_main.dart -d edge
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAnoBWmYeMAUF1X6Rg2NRTgWzdVSLowaro',
          authDomain: 'kelegance.firebaseapp.com',
          projectId: 'kelegance',
          storageBucket: 'kelegance.firebasestorage.app',
          messagingSenderId: '766009026310',
          appId: '1:766009026310:web:e7e3e6c8fa24cd2d8a6087',
          measurementId: 'G-5Z74K3NM09',
        ),
      );
    }
  } catch (e) {
    stdout.writeln('Firebase déjà initialisé (google-services) : $e');
  }

  stdout.writeln('Kelegance — injection liste officielle v2.4.3…');
  final rapport = await KeleganceInitFirestore.injecterListeOfficielleDepart();
  stdout.writeln(rapport.message);

  if (rapport.success) {
    final verification = await FirebaseFirestore.instance.collection('users').get();
    stdout.writeln('Vérification : ${verification.docs.length} documents dans users/ (total collection).');
  }

  exit(rapport.success ? 0 : 1);
}
