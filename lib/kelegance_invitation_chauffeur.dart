import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kelegance_web_urls.dart';

/// Invitation sécurisée — création de profil chauffeur collaborateur (`role=driver`).
abstract final class KeleganceInvitationChauffeur {
  static const String collection = 'invitations_chauffeur';

  static String _genererToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Crée le profil Firestore et retourne le lien de connexion sécurisé.
  static Future<String> creerEtGenererLien({
    required String prenom,
    required String nom,
    required String email,
    String? telephone,
  }) async {
    final emailNorm = email.toLowerCase().trim();
    if (!emailNorm.contains('@')) {
      throw ArgumentError('Adresse e-mail invalide.');
    }

    final token = _genererToken();
    final nomComplet = '$prenom $nom'.trim();
    final creePar = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();

    final profil = <String, dynamic>{
      'token': token,
      'email': emailNorm,
      'prenom': prenom.trim(),
      'nom': nom.trim(),
      'name': nomComplet.isNotEmpty ? nomComplet : emailNorm.split('@').first,
      if (telephone != null && telephone.trim().isNotEmpty) 'phone': telephone.trim(),
      'role': 'driver',
      'niveauAcces': 'collaborateur',
      'isApproved': true,
      'accesChauffeur': true,
      'bypassCerclePrive': true,
      'consomme': false,
      if (creePar != null) 'creePar': creePar,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection(collection).doc(token).set(profil);

    await FirebaseFirestore.instance.collection('users').doc(emailNorm).set(
      {
        ...profil,
        'invitationToken': token,
        'listeInvitation': true,
      },
      SetOptions(merge: true),
    );

    return KeleganceWebUrls.lienConnexionChauffeur(invite: token, email: emailNorm);
  }

  /// Applique une invitation après connexion (associe l'UID au profil chauffeur).
  static Future<void> appliquerInvitationSiPresente({
    required User user,
    String? token,
    String? emailAttendu,
  }) async {
    final invite = token?.trim();
    if (invite == null || invite.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance.collection(collection).doc(invite).get();
      if (!snap.exists) return;

      final data = snap.data();
      if (data == null || data['consomme'] == true) return;

      final emailInvite = (data['email']?.toString() ?? '').toLowerCase().trim();
      final emailUser = user.email?.toLowerCase().trim();
      if (emailInvite.isEmpty || emailUser == null) return;
      if (emailAttendu != null && emailAttendu.toLowerCase().trim() != emailUser) return;
      if (emailInvite != emailUser) return;

      final payload = <String, dynamic>{
        'role': 'driver',
        'niveauAcces': 'collaborateur',
        'email': emailUser,
        'isApproved': true,
        'accesChauffeur': true,
        'bypassCerclePrive': true,
        'invitationToken': invite,
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final cle in ['name', 'prenom', 'nom', 'phone']) {
        if (data[cle] != null) payload[cle] = data[cle];
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection(collection).doc(invite).set(
        {
          'consomme': true,
          'uid': user.uid,
          'consommeAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance invitation chauffeur: $e');
    }
  }

  static Future<void> copierLien(BuildContext context, String lien) async {
    await Clipboard.setData(ClipboardData(text: lien));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D52),
        content: Text('Lien de connexion chauffeur copié.'),
      ),
    );
  }
}
