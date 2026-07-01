import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'kelegance_documents_pdf_service.dart';
import 'kelegance_init_firestore.dart';

/// Niveaux d'accès console chauffeur — v1.0.10.
enum KeleganceNiveauAcces {
  /// Dispatch, annulations, QR complet, facturier, toutes les missions.
  brasDroit,

  /// Ses courses assignées et son coffre-fort perso uniquement.
  collaborateur,
}

/// Hiérarchie multi-rôles — e-mail officiel + champs Firestore (`role`, `niveauAcces`, etc.).
abstract final class KeleganceRoles {
  static const List<String> emailsBrasDroit = [
    KeleganceProfilsBootstrap.emailAdminNicolas,
    KeleganceProfilsBootstrap.emailAdminDeborah,
    KeleganceProfilsBootstrap.emailAdminLinel,
    KeleganceIdentiteDocuments.emailAdmin,
  ];

  static bool? _cacheBrasDroit;
  static final ValueNotifier<bool> notifierBrasDroit = ValueNotifier(false);

  static String? _normaliser(String? email) => email?.toLowerCase().trim();

  static bool _emailListeOfficielle(String? email) {
    final mail = _normaliser(email);
    if (mail == null || mail.isEmpty) return false;
    return emailsBrasDroit.any((e) => e.toLowerCase() == mail);
  }

  static String? _normaliserRoleFirestore(dynamic raw) {
    if (raw == null) return null;
    final role = raw.toString().toLowerCase().trim().replaceAll(' ', '_');
    if (role == 'admin' || role == 'administrateur') return 'admin';
    if (role == 'bras_droit' || role == 'brasdroit') return 'bras_droit';
    if (role == 'chauffeur' ||
        role == 'driver' ||
        role == 'conducteur' ||
        role == 'professionnel' ||
        role == 'professional') {
      return 'chauffeur';
    }
    return role.isEmpty ? null : role;
  }

  /// Indique si un document Firestore (`users` / `chauffeurs`) accorde les droits Bras Droit.
  static bool profilIndiqueBrasDroit(Map<String, dynamic>? data) {
    if (data == null) return false;

    final role = _normaliserRoleFirestore(data['role']);
    if (role == 'admin' || role == 'bras_droit') return true;

    final niveau = _normaliserRoleFirestore(data['niveauAcces']);
    if (niveau == 'admin' || niveau == 'bras_droit') return true;

    for (final cle in ['accesBrasDroit', 'accesAdmin', 'isAdmin', 'brasDroit']) {
      final v = data[cle];
      if (v == true || v == 'true' || v == 1) return true;
    }

    return _emailListeOfficielle(data['email']?.toString());
  }

  static void _appliquerCache(bool brasDroit) {
    _cacheBrasDroit = brasDroit;
    if (notifierBrasDroit.value != brasDroit) {
      notifierBrasDroit.value = brasDroit;
    }
  }

  static void invaliderCache() {
    _cacheBrasDroit = null;
    notifierBrasDroit.value = false;
  }

  static KeleganceNiveauAcces niveauPourEmail(String? email) {
    if (estBrasDroit(email)) return KeleganceNiveauAcces.brasDroit;
    return KeleganceNiveauAcces.collaborateur;
  }

  static KeleganceNiveauAcces niveauUtilisateurCourant() =>
      niveauPourEmail(FirebaseAuth.instance.currentUser?.email);

  static bool estBrasDroit([String? email]) {
    final courant = FirebaseAuth.instance.currentUser?.email;
    final mail = _normaliser(email ?? courant);

    if (_emailListeOfficielle(mail)) return true;

    if (email == null || _normaliser(email) == _normaliser(courant)) {
      return _cacheBrasDroit == true || notifierBrasDroit.value;
    }

    return false;
  }

  static bool estCollaborateur([String? email]) => !estBrasDroit(email);

  /// Chauffeur `role=driver` / collaborateur — sans tableau de bord admin global.
  static bool estChauffeurRestreint([String? email]) => !estBrasDroit(email);

  static bool accesOutilsAdmin([String? email]) => estBrasDroit(email);

  static bool peutVoirCaGlobal([String? email]) => estBrasDroit(email);

  static bool peutVoirPresenceEquipe([String? email]) =>
      FirebaseAuth.instance.currentUser != null;

  static bool peutGererInvitationsChauffeur([String? email]) => estBrasDroit(email);

  /// Bascule Console Chauffeur ↔ Mode Client — Bras Droit / Admin uniquement.
  static bool peutBasculerEntreModes([String? email]) => estBrasDroit(email);

  /// Routes `/admin` et `/console` — Bras Droit / Admin uniquement.
  static bool peutAccederRoutesAdmin([String? email]) => estBrasDroit(email);

  static Future<Map<String, dynamic>?> _profilBootstrapParEmail(String? email) async {
    final mail = _normaliser(email);
    if (mail == null || mail.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: mail)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        if (profilIndiqueBrasDroit(doc.data())) return doc.data();
      }
      if (snap.docs.isNotEmpty) return snap.docs.first.data();
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceRoles bootstrap email: $e');
    }
    return null;
  }

  /// Résolution complète Firestore + liste officielle pour l'utilisateur connecté.
  static Future<bool> resoudreBrasDroitDepuisFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = _normaliser(user?.email);
    if (user == null || email == null) return false;
    if (_emailListeOfficielle(email)) return true;

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        _profilBootstrapParEmail(email),
      ]);

      final chauffeurDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final usersDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final bootstrap = results[2] as Map<String, dynamic>?;

      final chauffeur = chauffeurDoc.data();
      final users = usersDoc.data();

      if (profilIndiqueBrasDroit(chauffeur) ||
          profilIndiqueBrasDroit(users) ||
          profilIndiqueBrasDroit(bootstrap)) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceRoles résolution Firestore: $e');
    }

    return false;
  }

  static Future<void> initialiserPourUtilisateurCourant() async {
    final email = _normaliser(FirebaseAuth.instance.currentUser?.email);
    if (_emailListeOfficielle(email)) {
      _appliquerCache(true);
    }
    final firestore = await resoudreBrasDroitDepuisFirestore();
    _appliquerCache(firestore || _emailListeOfficielle(email));
  }

  /// Écoute les mises à jour de rôle sur `users` et `chauffeurs`.
  /// Retourne une fonction `cancel` à appeler dans `dispose`.
  static void Function()? ecouterMisesAJour(VoidCallback onChange) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final subs = <StreamSubscription<dynamic>>[];

    Future<void> rafraichir() async {
      await initialiserPourUtilisateurCourant();
      onChange();
    }

    subs.add(
      FirebaseFirestore.instance.collection('chauffeurs').doc(uid).snapshots().listen(
        (_) => unawaited(rafraichir()),
        onError: (_) {},
      ),
    );
    subs.add(
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen(
        (_) => unawaited(rafraichir()),
        onError: (_) {},
      ),
    );

    return () {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    };
  }

  static Future<Map<String, dynamic>> diagnosticAcces() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    final chauffeur = user == null
        ? null
        : (await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get()).data();
    final users = user == null
        ? null
        : (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data();
    final bootstrap = await _profilBootstrapParEmail(email);

    final firestore = await resoudreBrasDroitDepuisFirestore();

    return {
      'email': email,
      'uid': user?.uid,
      'listeOfficielle': _emailListeOfficielle(email),
      'cacheBrasDroit': _cacheBrasDroit,
      'notifierBrasDroit': notifierBrasDroit.value,
      'firestoreBrasDroit': firestore,
      'accesEffectif': estBrasDroit(),
      'roleChauffeurs': chauffeur?['role'],
      'roleUsers': users?['role'],
      'niveauAccesChauffeurs': chauffeur?['niveauAcces'],
      'niveauAccesUsers': users?['niveauAcces'],
      'bootstrapRole': bootstrap?['role'],
      'bootstrapNiveau': bootstrap?['niveauAcces'],
    };
  }

  static bool missionAssigneeAuCollaborateur(
    Map<String, dynamic> data, {
    String? email,
    String? nom,
    String? uid,
  }) {
    final chauffeurUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    for (final cle in ['chauffeurId', 'chauffeurUid', 'uidChauffeur', 'chauffeurUidAssigne']) {
      final brut = data[cle]?.toString().trim();
      if (brut != null && brut.isNotEmpty && chauffeurUid != null && brut == chauffeurUid) {
        return true;
      }
    }

    final mail = _normaliser(email ?? FirebaseAuth.instance.currentUser?.email);
    final assigne = (data['chauffeurAssigne']?.toString() ?? '').toLowerCase().trim();
    if (assigne.isEmpty || mail == null) return false;
    if (assigne.contains(mail)) return true;
    final nomNorm = (nom ?? '').toLowerCase().trim();
    return nomNorm.isNotEmpty && assigne.contains(nomNorm);
  }

  static bool peutVoirMission(
    Map<String, dynamic> data, {
    String? email,
    String? nom,
    String? uid,
  }) {
    if (estBrasDroit(email)) return true;
    return missionAssigneeAuCollaborateur(data, email: email, nom: nom, uid: uid);
  }
}
