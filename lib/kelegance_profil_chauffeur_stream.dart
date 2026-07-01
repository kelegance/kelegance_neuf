import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'kelegance_bon_commande_service.dart';

/// Instantané profil chauffeur — fusion `users/{uid}` + `chauffeurs/{uid}`.
class KeleganceProfilChauffeurSnapshot {
  const KeleganceProfilChauffeurSnapshot({
    required this.uid,
    required this.chargement,
    this.data,
    this.erreur,
    this.nom,
    this.email,
    this.notificationPrefs,
  });

  final String uid;
  final bool chargement;
  final Map<String, dynamic>? data;
  final Object? erreur;
  final String? nom;
  final String? email;
  final Map<String, dynamic>? notificationPrefs;

  bool get nomDisponible => nom != null && nom!.trim().isNotEmpty;
}

/// Flux live du document utilisateur chauffeur (lecture `users` + `chauffeurs`).
abstract final class KeleganceProfilChauffeurStream {
  static String? _extraireNom(Map<String, dynamic>? data, User? user) {
    if (data != null && data.isNotEmpty) {
      var nom = KeleganceBonCommandeService.extraireNomAffichage(data);
      if (nom != 'Client' && nom.trim().isNotEmpty) return nom.trim();
    }
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final mail = user?.email?.trim();
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return null;
  }

  static Map<String, dynamic>? _extraireNotificationPrefs(Map<String, dynamic>? data) {
    final raw = data?['notificationPrefs'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static KeleganceProfilChauffeurSnapshot _fusionner({
    required String uid,
    required bool chargement,
    Map<String, dynamic>? users,
    Map<String, dynamic>? chauffeurs,
    Object? erreur,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final data = <String, dynamic>{
      ...?users,
      ...?chauffeurs,
    };
    final snap = KeleganceProfilChauffeurSnapshot(
      uid: uid,
      chargement: chargement,
      data: data.isEmpty ? null : data,
      erreur: erreur,
      nom: _extraireNom(data.isEmpty ? null : data, user),
      email: data['email']?.toString() ?? user?.email,
      notificationPrefs: _extraireNotificationPrefs(data.isEmpty ? null : data),
    );
    if (kDebugMode) {
      debugPrint(
        'KeleganceProfilChauffeur — uid=$uid chargement=$chargement '
        'nom=${snap.nom} erreur=$erreur docs=${data.length}',
      );
    }
    return snap;
  }

  /// Écoute les deux documents profil et fusionne les champs.
  static Stream<KeleganceProfilChauffeurSnapshot> ecouter() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(
        const KeleganceProfilChauffeurSnapshot(uid: '', chargement: false, erreur: 'Session absente'),
      );
    }

    final uid = user.uid;
    final controller = StreamController<KeleganceProfilChauffeurSnapshot>.broadcast();

    Map<String, dynamic>? usersData;
    Map<String, dynamic>? chauffeursData;
    Object? lastError;
    var usersReady = false;
    var chauffeursReady = false;

    void pousser() {
      if (controller.isClosed) return;
      controller.add(
        _fusionner(
          uid: uid,
          chargement: !usersReady || !chauffeursReady,
          users: usersData,
          chauffeurs: chauffeursData,
          erreur: lastError,
        ),
      );
    }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subUsers;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subChauffeurs;

    subUsers = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen(
      (snap) {
        usersData = snap.data();
        usersReady = true;
        lastError = null;
        pousser();
      },
      onError: (Object e) {
        lastError = e;
        usersReady = true;
        if (kDebugMode) debugPrint('KeleganceProfilChauffeur users/$uid: $e');
        pousser();
      },
    );

    subChauffeurs = FirebaseFirestore.instance.collection('chauffeurs').doc(uid).snapshots().listen(
      (snap) {
        chauffeursData = snap.data();
        chauffeursReady = true;
        lastError = null;
        pousser();
      },
      onError: (Object e) {
        lastError = e;
        chauffeursReady = true;
        if (kDebugMode) debugPrint('KeleganceProfilChauffeur chauffeurs/$uid: $e');
        pousser();
      },
    );

    controller.onCancel = () async {
      await subUsers?.cancel();
      await subChauffeurs?.cancel();
    };

    pousser();
    return controller.stream;
  }

  /// Lecture ponctuelle (fallback).
  static Future<KeleganceProfilChauffeurSnapshot> charger() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const KeleganceProfilChauffeurSnapshot(uid: '', chargement: false, erreur: 'Session absente');
    }
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get(),
      ]);
      return _fusionner(
        uid: user.uid,
        chargement: false,
        users: results[0].data(),
        chauffeurs: results[1].data(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceProfilChauffeur charger: $e');
      return KeleganceProfilChauffeurSnapshot(uid: user.uid, chargement: false, erreur: e);
    }
  }
}
