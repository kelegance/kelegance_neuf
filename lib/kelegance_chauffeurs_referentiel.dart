import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Profil chauffeur pour bon de commande réglementaire.
class KeleganceProfilChauffeurBdc {
  const KeleganceProfilChauffeurBdc({
    required this.nom,
    required this.telephone,
    required this.marque,
    required this.modele,
    required this.couleur,
    required this.plaque,
    this.email,
    this.uid,
    this.cle,
  });

  final String nom;
  final String telephone;
  final String marque;
  final String modele;
  final String couleur;
  final String plaque;
  final String? email;
  final String? uid;
  final String? cle;

  bool get estComplet =>
      nom.trim().isNotEmpty &&
      telephone.trim().isNotEmpty &&
      marque.trim().isNotEmpty &&
      modele.trim().isNotEmpty &&
      couleur.trim().isNotEmpty &&
      plaque.trim().isNotEmpty;

  String get vehiculeComplet => '$marque $modele'.trim();

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'telephone': telephone,
        'marque': marque,
        'modele': modele,
        'couleur': couleur,
        'plaque': plaque,
        if (email != null) 'email': email,
        if (uid != null) 'uid': uid,
        if (cle != null) 'cle': cle,
      };
}

/// Données chauffeur absentes ou incomplètes — pas de pré-remplissage par défaut.
class KeleganceChauffeurDonneesIncompletesException implements Exception {
  KeleganceChauffeurDonneesIncompletesException([this.detail]);

  final String? detail;

  static const String messageDefaut = 'Données chauffeur incomplètes';

  @override
  String toString() => detail == null || detail!.isEmpty ? messageDefaut : '$messageDefaut — $detail';
}

/// Référentiel chauffeurs — JSON embarqué + surcharge Firestore `profils_chauffeur/{uid}`.
abstract final class KeleganceChauffeursReferentiel {
  static const String _assetPath = 'assets/data/chauffeurs_data.json';
  static const String collection = 'profils_chauffeur';

  static List<Map<String, dynamic>>? _cacheJson;

  static Future<void> _chargerJson() async {
    if (_cacheJson != null) return;
    final brut = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(brut) as Map<String, dynamic>;
    final liste = decoded['chauffeurs'];
    _cacheJson = liste is List
        ? liste.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  static String _normaliser(String? raw) =>
      (raw ?? '').toLowerCase().trim().replaceAll('é', 'e').replaceAll('è', 'e');

  static KeleganceProfilChauffeurBdc? _depuisMap(Map<String, dynamic> data, {String? uid}) {
    final profil = KeleganceProfilChauffeurBdc(
      nom: data['nom']?.toString().trim() ?? '',
      telephone: data['telephone']?.toString().trim() ?? data['phone']?.toString().trim() ?? '',
      marque: data['marque']?.toString().trim() ?? '',
      modele: data['modele']?.toString().trim() ?? '',
      couleur: data['couleur']?.toString().trim() ?? '',
      plaque: data['plaque']?.toString().trim() ?? data['immatriculation']?.toString().trim() ?? '',
      email: data['email']?.toString().trim().toLowerCase(),
      uid: uid ?? data['uid']?.toString(),
      cle: data['cle']?.toString(),
    );
    return profil.estComplet ? profil : null;
  }

  static Future<KeleganceProfilChauffeurBdc?> _parUidFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
      final data = doc.data();
      if (data == null) return null;
      return _depuisMap(data, uid: uid);
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceChauffeursReferentiel uid=$uid: $e');
      return null;
    }
  }

  static Future<KeleganceProfilChauffeurBdc?> _parEmailFirestore(String email) async {
    final mail = email.toLowerCase().trim();
    if (!mail.contains('@')) return null;
    try {
      for (final col in ['profils_chauffeur', 'chauffeurs', 'users']) {
        final snap = await FirebaseFirestore.instance
            .collection(col)
            .where('email', isEqualTo: mail)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) continue;
        final profil = _depuisMap(snap.docs.first.data(), uid: snap.docs.first.id);
        if (profil != null) return profil;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceChauffeursReferentiel email=$mail: $e');
    }
    return null;
  }

  static Future<KeleganceProfilChauffeurBdc?> _parJson(String identifiant) async {
    await _chargerJson();
    final needle = _normaliser(identifiant);
    if (needle.isEmpty) return null;

    for (final entry in _cacheJson ?? const <Map<String, dynamic>>[]) {
      final email = _normaliser(entry['email']?.toString());
      final nom = _normaliser(entry['nom']?.toString());
      final cle = _normaliser(entry['cle']?.toString());
      final aliases = (entry['aliases'] as List?)?.map((a) => _normaliser(a.toString())).toList() ?? [];

      final match = needle == email ||
          needle == nom ||
          needle == cle ||
          aliases.contains(needle) ||
          (nom.isNotEmpty && (nom.contains(needle) || needle.contains(nom))) ||
          (email.isNotEmpty && needle.contains(email));

      if (match) return _depuisMap(entry);
    }
    return null;
  }

  /// Résout un profil via UID mission, e-mail ou nom affiché.
  static Future<KeleganceProfilChauffeurBdc?> resoudre({
    String? uid,
    String? emailOuNom,
  }) async {
    final idUid = uid?.trim();
    if (idUid != null && idUid.isNotEmpty) {
      final firestore = await _parUidFirestore(idUid);
      if (firestore != null) return firestore;
    }

    final identifiant = emailOuNom?.trim();
    if (identifiant != null && identifiant.isNotEmpty) {
      if (identifiant.contains('@')) {
        final parEmailFs = await _parEmailFirestore(identifiant);
        if (parEmailFs != null) return parEmailFs;
      }
      final parJson = await _parJson(identifiant);
      if (parJson != null) return parJson;
    }

    if (idUid != null && idUid.isNotEmpty) {
      return _parJson(idUid);
    }
    return null;
  }

  static Future<KeleganceProfilChauffeurBdc?> resoudreDepuisMission(Map<String, dynamic> mission) async {
    final uid = mission['chauffeurUid']?.toString().trim() ??
        mission['chauffeurId']?.toString().trim() ??
        mission['uidChauffeur']?.toString().trim();
    final assigne = mission['chauffeurAssigne']?.toString().trim();
    return resoudre(uid: uid, emailOuNom: assigne);
  }

  /// Lève [KeleganceChauffeurDonneesIncompletesException] si profil absent ou incomplet.
  static Future<KeleganceProfilChauffeurBdc> exigerDepuisMission(Map<String, dynamic> mission) async {
    final profil = await resoudreDepuisMission(mission);
    if (profil == null || !profil.estComplet) {
      final assigne = mission['chauffeurAssigne']?.toString() ?? '—';
      throw KeleganceChauffeurDonneesIncompletesException(
        'Aucun profil complet pour « $assigne ». Assignez un chauffeur référencé avant validation.',
      );
    }
    return profil;
  }
}
