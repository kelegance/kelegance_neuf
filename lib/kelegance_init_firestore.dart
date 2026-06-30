import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// E-mail super administrateur — bypass cercle privé + accès chauffeur (v2.3.0).
abstract final class KeleganceProfilsBootstrap {
  static const String emailAdminNicolas = 'nicolas.nbchauffeurs@gmail.com';
  static const String emailAdminDeborah = 'deborah.jetil@gmail.com';
  static const String emailAdminLinel = 'linel.marcalexandrepro@gmail.com';

  /// E-mails autorisés pour les outils admin (QR codes, etc.).
  static const List<String> emailsAdmin = [
    emailAdminNicolas,
    emailAdminDeborah,
    emailAdminLinel,
  ];
}

/// Utilisateur officiel Kélégance — liste de départ v2.3.0.
class KeleganceUtilisateurOfficiel {
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isApproved;
  final bool bypassCerclePrive;
  final bool accesChauffeur;
  final bool accesClient;

  const KeleganceUtilisateurOfficiel({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isApproved = true,
    this.bypassCerclePrive = false,
    this.accesChauffeur = false,
    this.accesClient = true,
  });

  String get emailNormalise => email.toLowerCase().trim();

  /// ID document Firestore = e-mail normalisé (recherche par `where email ==`).
  String get docId => emailNormalise;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': emailNormalise,
      'phone': phone,
      'role': role,
      if (accesChauffeur && KeleganceProfilsBootstrap.emailsAdmin.contains(emailNormalise))
        'niveauAcces': 'bras_droit',
      'isApproved': isApproved,
      if (bypassCerclePrive) 'bypassCerclePrive': true,
      if (accesChauffeur) 'accesChauffeur': true,
      if (accesClient) 'accesClient': true,
      'listeOfficielleDepart': true,
      'versionInjection': '2.4.3',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toChauffeurFirestore() {
    return {
      'name': name,
      'email': emailNormalise,
      'phone': phone,
      'role': 'chauffeur',
      if (KeleganceProfilsBootstrap.emailsAdmin.contains(emailNormalise)) 'niveauAcces': 'bras_droit',
      'isApproved': true,
      'bypassCerclePrive': true,
      'status': 'HORS_LIGNE',
      'listeOfficielleDepart': true,
      'versionInjection': '2.4.3',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Liste officielle de départ — collection `users` (v2.3.0).
abstract final class KeleganceListeOfficielleDepart {
  static const List<KeleganceUtilisateurOfficiel> utilisateurs = [
    KeleganceUtilisateurOfficiel(
      name: 'Nicolas',
      email: 'nicolas.nbchauffeurs@gmail.com',
      phone: '',
      role: 'client',
      isApproved: true,
      bypassCerclePrive: true,
      accesChauffeur: true,
      accesClient: true,
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Déborah Jetil',
      email: 'deborah.jetil@gmail.com',
      phone: '06 65 58 73 60',
      role: 'chauffeur',
      bypassCerclePrive: true,
      accesChauffeur: true,
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Marc Alexandre Linel',
      email: 'linel.marcalexandrepro@gmail.com',
      phone: '06 72 16 69 53',
      role: 'chauffeur',
      bypassCerclePrive: true,
      accesChauffeur: true,
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Caroline Guegain',
      email: 'cguegain@aktefact.fr',
      phone: '06 22 68 12 49',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Guillaume Letenneur',
      email: 'gletenneur@yahoo.com',
      phone: '06 15 20 69 79',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Greg',
      email: 'gregphoto@yahoo.fr',
      phone: '06 09 27 90 69',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Raquel Archas',
      email: 'raquelarchas@gmail.com',
      phone: '06 31 99 47 34',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Christelle Thullier',
      email: 'christelle.thullier@marie.fr',
      phone: '06 84 49 98 65',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Lory Emmanuelle',
      email: 'emmanuelle.lory@wanadoo.fr',
      phone: '06 47 13 08 18',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Simone & Nelson',
      email: 'emmanuelle@simoneetnelson.com',
      phone: '06 47 13 08 18',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Françoise Bonvarlet',
      email: 'drbonvarlet@hotmail.fr',
      phone: '06 17 25 09 18',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Céline Letenneur',
      email: 'c.letenneur@orange.fr',
      phone: '06 67 01 09 71',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Christophe Poirmeur',
      email: 'christophe.poirmeur@stilog.com',
      phone: '06 07 54 28 88',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Mariam',
      email: 'mariam.elfanidi@gmail.com',
      phone: '06 11 08 42 96',
      role: 'client',
    ),
    KeleganceUtilisateurOfficiel(
      name: 'Françoise Maréchal',
      email: 'fmal@orange.fr',
      phone: '06 72 56 08 55',
      role: 'client_vip',
    ),
  ];
}

/// Résultat d'injection Firestore.
class KeleganceRapportInjection {
  final bool success;
  final int usersEcrits;
  final int chauffeursEcrits;
  final String message;

  const KeleganceRapportInjection({
    required this.success,
    required this.usersEcrits,
    required this.chauffeursEcrits,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Initialise la liste officielle dans Firestore (merge — sans écraser les UID liés).
abstract final class KeleganceInitFirestore {
  static KeleganceRapportInjection? dernierRapport;

  /// Alias historique — appelé au démarrage de l'app.
  static Future<void> initialiserProfilsTest() => injecterListeOfficielleDepart();

  static Future<KeleganceRapportInjection> injecterListeOfficielleDepart() async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      var chauffeurs = 0;

      for (final user in KeleganceListeOfficielleDepart.utilisateurs) {
        final refUser = db.collection('users').doc(user.docId);
        batch.set(refUser, user.toFirestore(), SetOptions(merge: true));

        if (user.role == 'chauffeur') {
          final refChauffeur = db.collection('chauffeurs').doc(user.docId);
          batch.set(refChauffeur, user.toChauffeurFirestore(), SetOptions(merge: true));
          chauffeurs++;
        }
      }

      await batch.commit();

      var verifies = 0;
      for (final user in KeleganceListeOfficielleDepart.utilisateurs) {
        final doc = await db.collection('users').doc(user.docId).get();
        if (doc.exists && doc.data()?['listeOfficielleDepart'] == true) verifies++;
      }

      final rapport = KeleganceRapportInjection(
        success: verifies == KeleganceListeOfficielleDepart.utilisateurs.length,
        usersEcrits: verifies,
        chauffeursEcrits: chauffeurs,
        message:
            'Kelegance v2.4.3 — $verifies/${KeleganceListeOfficielleDepart.utilisateurs.length} profils '
            'vérifiés dans users/ ($chauffeurs chauffeurs attendus dans chauffeurs/).',
      );
      dernierRapport = rapport;
      debugPrint(rapport.message);
      return rapport;
    } catch (e) {
      final rapport = KeleganceRapportInjection(
        success: false,
        usersEcrits: 0,
        chauffeursEcrits: 0,
        message: 'Kelegance Init Firestore échec: $e',
      );
      dernierRapport = rapport;
      debugPrint(rapport.message);
      return rapport;
    }
  }
}
