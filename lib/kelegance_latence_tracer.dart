import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'kelegance_missions_service.dart';
import 'kelegance_roles.dart';

/// Mesure la latence validation/dispatch admin → affichage chauffeur.
/// Logs visibles via `adb logcat -s KeleganceLatence`.
abstract final class KeleganceLatenceTracer {
  static const String _tag = 'KeleganceLatence';

  /// Horodatage local admin au moment du clic (avant round-trip Firestore).
  static final Map<String, int> _emisLocalesAdmin = {};
  static final Set<String> _missionsAcquitteesAdmin = {};
  static final Set<String> _missionsAcquitteesChauffeur = {};

  static void log(String message) {
    if (kDebugMode) debugPrint('$_tag — $message');
  }

  /// Appelé côté admin avant/après validation ou dispatch.
  static Future<void> marquerEmissionAdmin({
    required String missionId,
    required String action,
    String? chauffeurCible,
  }) async {
    if (!KeleganceRoles.accesOutilsAdmin()) return;

    final t0 = DateTime.now().millisecondsSinceEpoch;
    _emisLocalesAdmin[missionId] = t0;
    final admin = FirebaseAuth.instance.currentUser;

    log(
      'ÉMISSION action=$action mission=$missionId chauffeur=${chauffeurCible ?? "—"} '
      't0=$t0 admin=${admin?.uid}',
    );

    try {
      await FirebaseFirestore.instance.collection('missions').doc(missionId).set(
        {
          'latenceTrace': {
            'action': action,
            'emisAdminLe': FieldValue.serverTimestamp(),
            'emisAdminClientMs': t0,
            'adminUid': admin?.uid,
            'chauffeurCible': chauffeurCible,
            'recuChauffeurClientMs': FieldValue.delete(),
            'recuChauffeurLe': FieldValue.delete(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      log('ERREUR écriture trace mission=$missionId : $e');
    }
  }

  /// Traite chaque snapshot missions — admin mesure E2E, chauffeur acquitte réception.
  static Future<void> traiterSnapshotMissions(KeleganceMissionsSnapshot snap) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final estAdmin = KeleganceRoles.accesOutilsAdmin();
    final maintenant = DateTime.now().millisecondsSinceEpoch;

    for (final change in snap.changes) {
      if (change.type == DocumentChangeType.removed) continue;
      final raw = change.doc.data();
      if (raw is! Map<String, dynamic>) continue;
      final data = raw;

      final trace = data['latenceTrace'];
      if (trace is! Map) continue;
      final traceMap = Map<String, dynamic>.from(trace);
      final missionId = change.doc.id;

      final emisAdminMs = _lireMs(traceMap['emisAdminClientMs']);
      final recuChauffeurMs = _lireMs(traceMap['recuChauffeurClientMs']);

      if (estAdmin) {
        _traiterCoteAdmin(
          missionId: missionId,
          emisAdminMs: emisAdminMs,
          recuChauffeurMs: recuChauffeurMs,
          maintenant: maintenant,
          depuisCache: snap.premierChargement == false && _emisLocalesAdmin.containsKey(missionId),
        );
        continue;
      }

      if (emisAdminMs == null || recuChauffeurMs != null) continue;
      if (_missionsAcquitteesChauffeur.contains(missionId)) continue;
      if (!KeleganceRoles.missionAssigneeAuCollaborateur(data)) continue;

      _missionsAcquitteesChauffeur.add(missionId);
      final deltaMs = maintenant - emisAdminMs;
      log(
        'RÉCEPTION chauffeur mission=$missionId delta=${deltaMs}ms '
        '(depuis validation admin)',
      );

      try {
        await FirebaseFirestore.instance.collection('missions').doc(missionId).set(
          {
            'latenceTrace': {
              'recuChauffeurClientMs': maintenant,
              'recuChauffeurLe': FieldValue.serverTimestamp(),
              'recuChauffeurUid': uid,
            },
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        log('ERREUR acquittement chauffeur mission=$missionId : $e');
      }
    }
  }

  static void _traiterCoteAdmin({
    required String missionId,
    required int? emisAdminMs,
    required int? recuChauffeurMs,
    required int maintenant,
    required bool depuisCache,
  }) {
    final t0Local = _emisLocalesAdmin[missionId] ?? emisAdminMs;

    if (t0Local != null && !_missionsAcquitteesAdmin.contains('local_$missionId')) {
      final deltaListener = maintenant - t0Local;
      log(
        'SNAPSHOT admin mission=$missionId deltaListener=${deltaListener}ms '
        '(clic admin → snapshot local)',
      );
      _missionsAcquitteesAdmin.add('local_$missionId');
    }

    if (emisAdminMs == null || recuChauffeurMs == null) return;
    if (_missionsAcquitteesAdmin.contains('e2e_$missionId')) return;

    _missionsAcquitteesAdmin.add('e2e_$missionId');
    final deltaE2E = recuChauffeurMs - emisAdminMs;
    log(
      'E2E mission=$missionId delta=${deltaE2E}ms '
      '(validation admin → téléphone chauffeur)',
    );
  }

  static int? _lireMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  static void reinitialiserSession() {
    _emisLocalesAdmin.clear();
    _missionsAcquitteesAdmin.clear();
    _missionsAcquitteesChauffeur.clear();
  }
}
