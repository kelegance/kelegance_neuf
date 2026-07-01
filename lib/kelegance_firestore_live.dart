import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Configuration et écoute Firestore optimisée — latence minimale, pas de cache bloquant l'UI.
abstract final class KeleganceFirestoreLive {
  static bool _configure = false;

  /// À appeler une fois après [Firebase.initializeApp].
  static Future<void> configurer() async {
    if (_configure) return;
    try {
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: !kIsWeb,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _configure = true;
      _log('Firestore configuré — persistence=${!kIsWeb}');
    } catch (e) {
      _log('configuration Firestore: $e');
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('KeleganceLive — $message');
  }

  /// Snapshot listener sans métadonnées — ignore les événements purement cache si [ignorerCacheSeul].
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> ecouterRequete({
    required Query<Map<String, dynamic>> requete,
    required String etiquette,
    required void Function(QuerySnapshot<Map<String, dynamic>> snap) onData,
    void Function(Object error)? onError,
    bool ignorerCacheSeul = true,
  }) {
    return requete.snapshots(includeMetadataChanges: false).listen(
      (snap) {
        final depuisCache = snap.metadata.isFromCache;
        final hasPending = snap.metadata.hasPendingWrites;
        if (ignorerCacheSeul && depuisCache && !hasPending) {
          _log('$etiquette — ignoré (cache local, en attente serveur)');
          return;
        }
        final latenceMs = DateTime.now().millisecondsSinceEpoch;
        _log(
          '$etiquette — ${snap.docs.length} doc(s) cache=$depuisCache pending=$hasPending',
        );
        onData(snap);
        if (kDebugMode && snap.docChanges.isNotEmpty) {
          for (final change in snap.docChanges) {
            _log('$etiquette Δ ${change.type.name} ${change.doc.id} @${latenceMs}ms');
          }
        }
      },
      onError: onError ?? (e) => _log('$etiquette ERREUR: $e'),
    );
  }

  /// Écoute document unique — même politique cache.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> ecouterDocument({
    required DocumentReference<Map<String, dynamic>> ref,
    required String etiquette,
    required void Function(DocumentSnapshot<Map<String, dynamic>> snap) onData,
    void Function(Object error)? onError,
    bool ignorerCacheSeul = true,
  }) {
    return ref.snapshots(includeMetadataChanges: false).listen(
      (snap) {
        final depuisCache = snap.metadata.isFromCache;
        if (ignorerCacheSeul && depuisCache && !snap.metadata.hasPendingWrites) {
          _log('$etiquette/${ref.id} — ignoré (cache)');
          return;
        }
        onData(snap);
      },
      onError: onError ?? (e) => _log('$etiquette ERREUR: $e'),
    );
  }

  /// Lecture ponctuelle serveur — jamais le cache pour les états critiques.
  static Future<DocumentSnapshot<Map<String, dynamic>>> lireServeur(
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    return ref.get(const GetOptions(source: Source.server));
  }
}
