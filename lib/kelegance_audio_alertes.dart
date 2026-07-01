import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Alertes audio chauffeur — sons intégrés au projet (assets + notifications natives).
abstract final class KeleganceAudioAlertes {
  static final AudioPlayer _instantPlayer = AudioPlayer(playerId: 'kelegance_instant');
  static final AudioPlayer _notificationPlayer = AudioPlayer(playerId: 'kelegance_notif');

  /// Boucle plein écran — course instantanée / popup alerte.
  static const String sonCourseInstantanee = 'sounds/course_instantanee.mp3';

  /// Ping court — nouvelle course assignée (FCM + notification locale).
  static const String sonNouvelleCourse = 'sounds/alerte_notification.mp3';

  /// Identifiant canal Android + fichier res/raw (sans extension).
  static const String canalAndroidNouvelleCourse = 'kelegance_nouvelle_course';
  static const String rawAndroidNouvelleCourse = 'nouvelle_course';

  /// Fichier bundle iOS pour APNs / DarwinNotificationDetails.
  static const String sonIosNouvelleCourse = 'nouvelle_course.mp3';

  static const double _vitesseCourseInstantanee = 1.2;
  static double _volumeAlerte = 1.0;
  static bool _initialise = false;
  static bool _boucleInstantActive = false;
  static StreamSubscription<void>? _finInstantSub;

  static AudioPlayer get audioPlayer => _instantPlayer;

  static void definirVolumeAlerte(double volume) {
    _volumeAlerte = volume.clamp(0.0, 1.0);
    unawaited(_instantPlayer.setVolume(_volumeAlerte));
  }

  static Future<void> _configurerLecteurInstant() async {
    await audioPlayer.setPlaybackRate(_vitesseCourseInstantanee);
    await audioPlayer.setVolume(_volumeAlerte);
  }

  static Future<void> _jouerSecurise(AudioPlayer player, AssetSource source, {required String label}) async {
    try {
      await player.play(source);
      _log('AUDIO OK [$label] : ${source.path}');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('KeleganceAudio — $message');
  }

  static Future<void> initialiser() async {
    if (_initialise) return;
    try {
      await _finInstantSub?.cancel();
      await _configurerLecteurInstant();
      _finInstantSub = audioPlayer.onPlayerComplete.listen((_) async {
        if (!_boucleInstantActive) return;
        try {
          await _configurerLecteurInstant();
          await audioPlayer.play(AssetSource(sonCourseInstantanee));
        } catch (e) {
          _log('ERREUR AUDIO CRITIQUE : $e');
        }
      });
      _initialise = true;
      _log('initialisé');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> playInstantRequestSound() async {
    try {
      await initialiser();
      _boucleInstantActive = true;
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _configurerLecteurInstant();
      await _jouerSecurise(audioPlayer, AssetSource(sonCourseInstantanee), label: 'course instantanée');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> stopInstantRequestSound() async {
    try {
      _boucleInstantActive = false;
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.release);
      _log('son course arrêté');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> playNotificationSound() async {
    try {
      await initialiser();
      await _notificationPlayer.stop();
      await _notificationPlayer.setReleaseMode(ReleaseMode.release);
      await _jouerSecurise(_notificationPlayer, AssetSource(sonNouvelleCourse), label: 'nouvelle course');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> liberer() async {
    try {
      _boucleInstantActive = false;
      await audioPlayer.stop();
      await _notificationPlayer.stop();
      _log('sons arrêtés');
    } catch (e) {
      _log('ERREUR AUDIO CRITIQUE : $e');
    }
  }
}
