import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kelegance_init_firestore.dart';
import 'kelegance_invitation_chauffeur.dart';
import 'kelegance_bon_commande_service.dart';
import 'kelegance_factures_service.dart';
import 'kelegance_missions_service.dart';
import 'kelegance_presence_service.dart';
import 'kelegance_roles.dart';
import 'kelegance_notification_service.dart';
import 'reveil_missions_service.dart';

class AuthService {
  static const String roleSessionKey = 'kelegance_auth_role_v215';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  /// Persistance locale — session maintenue jusqu'à déconnexion explicite (v3.0.0).
  static Future<void> configurerPersistance() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Native : persistance Firebase par défaut ; Web anciennes versions.
    }
  }

  static Future<void> sauvegarderRoleSession(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(roleSessionKey, role);
  }

  static Future<String?> chargerRoleSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(roleSessionKey);
  }

  static Future<void> effacerRoleSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(roleSessionKey);
  }

  static String? _normaliserRole(dynamic raw) {
    if (raw == null) return null;
    final role = raw.toString().toLowerCase().trim();
    if (role == 'admin' || role == 'administrateur') return 'admin';
    if (role == 'chauffeur' ||
        role == 'driver' ||
        role == 'conducteur' ||
        role == 'professionnel' ||
        role == 'professional') {
      return 'chauffeur';
    }
    if (role == 'client' || role == 'passager') return 'client';
    return null;
  }

  static bool _estApprouve(Map<String, dynamic>? data) {
    if (data == null) return false;
    final approved = data['isApproved'];
    return approved == true || approved == 'true' || approved == 1;
  }

  static bool _bypassCerclePrive(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (_estApprouve(data)) return true;
    final bypass = data['bypassCerclePrive'];
    return bypass == true || bypass == 'true' || bypass == 1;
  }

  static bool _estProfilAdmin(Map<String, dynamic>? data, String? email) {
    if (KeleganceRoles.profilIndiqueBrasDroit(data)) return true;
    final mail = email?.toLowerCase().trim();
    return mail != null && KeleganceProfilsBootstrap.emailsAdmin.any((e) => e.toLowerCase() == mail);
  }

  static bool _aAccesChauffeur(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = _normaliserRole(data['role']);
    return role == 'chauffeur' ||
        role == 'admin' ||
        data['accesChauffeur'] == true;
  }

  /// Cherche un profil bootstrap ou validé par e-mail dans `users`.
  static Future<Map<String, dynamic>?> _profilParEmail(String? email) async {
    final mail = email?.toLowerCase().trim();
    if (mail == null || mail.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: mail)
          .limit(10)
          .get();

      Map<String, dynamic>? chauffeur;
      Map<String, dynamic>? admin;
      Map<String, dynamic>? client;

      for (final doc in snap.docs) {
        final data = doc.data();
        final role = _normaliserRole(data['role']);
        if (role == 'chauffeur') chauffeur = data;
        if (role == 'admin') admin = data;
        if (role == 'client') client = data;
      }
      return chauffeur ?? admin ?? client;
    } catch (e) {
      debugPrint('Kelegance profil par email: $e');
    }
    return null;
  }

  static Future<void> _synchroniserProfilChauffeurUid(User user, {Map<String, dynamic>? source}) async {
    final email = user.email?.toLowerCase().trim();
    final roleFirestore = source?['role']?.toString().toLowerCase().trim();
    final payload = <String, dynamic>{
      'role': roleFirestore == 'driver' ? 'driver' : 'chauffeur',
      'email': email,
      'isApproved': true,
      'bypassCerclePrive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (source != null) {
      if (source['name'] != null) payload['name'] = source['name'];
      if (source['prenom'] != null) payload['prenom'] = source['prenom'];
      if (source['nom'] != null) payload['nom'] = source['nom'];
      if (source['phone'] != null) payload['phone'] = source['phone'];
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(payload, SetOptions(merge: true));
  }

  static Future<void> _synchroniserProfilClientUid(User user, {Map<String, dynamic>? source}) async {
    final email = user.email?.toLowerCase().trim();
    final payload = <String, dynamic>{
      'role': 'client',
      'email': email,
      'isApproved': source != null ? (_bypassCerclePrive(source) || _estApprouve(source)) : false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (source?['name'] != null) payload['name'] = source!['name'];
    if (source?['prenom'] != null) payload['prenom'] = source!['prenom'];
    if (source?['nom'] != null) payload['nom'] = source!['nom'];
    if (source?['phone'] != null) payload['phone'] = source!['phone'];

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
  }

  static bool _estProfilProfessionnel({
    required bool hasChauffeurDoc,
    Map<String, dynamic>? userData,
    Map<String, dynamic>? chauffeurData,
    Map<String, dynamic>? bootstrap,
  }) {
    if (hasChauffeurDoc) return true;
    if (_normaliserRole(userData?['role']) == 'chauffeur') return true;
    if (_normaliserRole(bootstrap?['role']) == 'chauffeur') return true;
    if (_aAccesChauffeur(userData) || _aAccesChauffeur(chauffeurData) || _aAccesChauffeur(bootstrap)) {
      return true;
    }
    return false;
  }

  /// Après connexion salon : oriente la session selon le profil Firestore (v3.0.1).
  static Future<void> orienterSessionApresConnexion(User user) async {
    final uid = user.uid;
    final email = user.email?.toLowerCase().trim();
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('chauffeurs').doc(uid).get(),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);
      final chauffeurDoc = results[0];
      final userData = results[1].data();
      final bootstrap = await _profilParEmail(email);
      final hasChauffeurDoc =
          chauffeurDoc.exists && _normaliserRole(chauffeurDoc.data()?['role']) != 'client';
      final estPro = _estProfilProfessionnel(
        hasChauffeurDoc: hasChauffeurDoc,
        userData: userData,
        chauffeurData: chauffeurDoc.data(),
        bootstrap: bootstrap,
      );
      if (estPro) {
        await declarerProfilChauffeur(user);
      } else {
        await declarerProfilClient(user);
      }
    } catch (e) {
      debugPrint('Kelegance orientation session: $e');
      await declarerProfilClient(user);
    }
  }

  /// Lecture Firestore — aiguillage client / chauffeur (v3.0.1).
  /// Retourne : `chauffeur` | `client`.
  static Future<String> resoudreRoleDepuisFirestore(User user) async {
    final uid = user.uid;
    final email = user.email?.toLowerCase().trim();
    final session = await chargerRoleSession();

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('chauffeurs').doc(uid).get(),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);
      final chauffeurDoc = results[0];
      final userDoc = results[1];
      final userData = userDoc.data();
      final chauffeurData = chauffeurDoc.data();
      final bootstrap = await _profilParEmail(email);

      final roleUsers = _normaliserRole(userData?['role']);
      final isAdmin = _estProfilAdmin(userData, email) || _estProfilAdmin(bootstrap, email);
      final hasChauffeurDoc =
          chauffeurDoc.exists && _normaliserRole(chauffeurData?['role']) != 'client';
      final estPro = _estProfilProfessionnel(
        hasChauffeurDoc: hasChauffeurDoc,
        userData: userData,
        chauffeurData: chauffeurData,
        bootstrap: bootstrap,
      );

      // Priorité 1 — session professionnelle explicite
      if (session == 'chauffeur' && (estPro || isAdmin)) {
        if (!hasChauffeurDoc) {
          await _synchroniserProfilChauffeurUid(user, source: bootstrap ?? userData);
        }
        return 'chauffeur';
      }

      // Priorité 2 — profil pro Firestore : console directe (déblocage Nicolas)
      if (estPro) {
        if (!hasChauffeurDoc) {
          await _synchroniserProfilChauffeurUid(user, source: bootstrap ?? userData);
        }
        if (session != 'chauffeur') {
          await sauvegarderRoleSession('chauffeur');
        }
        return 'chauffeur';
      }

      // Priorité 3 — admin sans profil chauffeur : suit la session
      if (isAdmin) {
        return session == 'chauffeur' ? 'chauffeur' : 'client';
      }

      // Priorité 4 — client
      if (roleUsers == 'client' || session == 'client') {
        return 'client';
      }
    } catch (e) {
      debugPrint('Kelegance résolution rôle Firestore: $e');
      if (session == 'chauffeur') return 'chauffeur';
    }
    return 'client';
  }

  /// Vérifie l'accès au cercle privé (`isApproved` / admin / bootstrap).
  static Future<bool> estClientApprouve(User user) async {
    final email = user.email?.toLowerCase().trim();
    if (email == null || email.isEmpty) return false;

    if (email == KeleganceProfilsBootstrap.emailAdminNicolas.toLowerCase()) {
      return true;
    }

    try {
      final session = await chargerRoleSession();
      if (session == 'chauffeur') return false;

      final docUid = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final uidData = docUid.data();
      final roleUid = _normaliserRole(uidData?['role']);
      if (roleUid == 'chauffeur') return false;

      if (_estProfilAdmin(uidData, email) || _bypassCerclePrive(uidData) || _estApprouve(uidData)) {
        return true;
      }

      final bootstrap = await _profilParEmail(email);
      if (bootstrap != null) {
        if (_normaliserRole(bootstrap['role']) == 'chauffeur') return false;
        if (_estProfilAdmin(bootstrap, email) ||
            _bypassCerclePrive(bootstrap) ||
            _estApprouve(bootstrap)) {
          await _synchroniserProfilClientUid(user, source: bootstrap);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Kelegance vérification accès privé: $e');
      if (email == KeleganceProfilsBootstrap.emailAdminNicolas.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  static Future<void> declarerProfilClient(User user) async {
    final email = user.email?.toLowerCase().trim();
    final bootstrap = await _profilParEmail(email);

    if (bootstrap != null) {
      final role = _normaliserRole(bootstrap['role']);
      if (role == 'chauffeur' || _aAccesChauffeur(bootstrap)) {
        await declarerProfilChauffeur(user);
        return;
      }
      if (role == 'admin' || _estProfilAdmin(bootstrap, email)) {
        await _synchroniserProfilClientUid(user, source: bootstrap);
        return;
      }
      if (_bypassCerclePrive(bootstrap) || _estApprouve(bootstrap)) {
        await _synchroniserProfilClientUid(user, source: bootstrap);
        return;
      }
    }

    await sauvegarderRoleSession('client');
    await _synchroniserProfilClientUid(user);
  }

  static Future<void> declarerProfilChauffeur(User user, {String? tokenInvitation}) async {
    await sauvegarderRoleSession('chauffeur');
    final bootstrap = await _profilParEmail(user.email?.toLowerCase().trim());
    await _synchroniserProfilChauffeurUid(user, source: bootstrap);
    final invite = tokenInvitation ?? (kIsWeb ? Uri.base.queryParameters['invite'] : null);
    await KeleganceInvitationChauffeur.appliquerInvitationSiPresente(
      user: user,
      token: invite,
      emailAttendu: user.email,
    );
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint('Erreur de connexion : $e');
      return null;
    }
  }

  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint("Erreur d'inscription : $e");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await KelegancePresenceService.declarerHorsLigne();
      await effacerRoleSession();
      KeleganceRoles.invaliderCache();
      await KeleganceMissionsService.arreter();
      await KeleganceFacturesService.arreter();
      await KelegancePresenceService.arreter();
      await KeleganceBonCommandeService.arreter();
      await KeleganceNotificationService.arreter();
      if (!kIsWeb) {
        await KeleganceReveilMissions.arreterSynchronisationFirestore();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Erreur de déconnexion : $e');
    }
  }
}
