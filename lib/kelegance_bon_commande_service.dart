import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'kelegance_roles.dart';

/// Données d'un bon de commande retour numérique.
class KeleganceBonCommandeRetour {
  const KeleganceBonCommandeRetour({
    required this.clientNom,
    required this.dateTransfert,
    required this.destination,
    required this.montant,
    this.clientEmail,
    this.clientId,
    this.statut = 'En attente',
  });

  final String clientNom;
  final String? clientEmail;
  final String? clientId;
  final DateTime dateTransfert;
  final String destination;
  final double montant;
  final String statut;
}

/// Client Firestore résolu par e-mail — avant création du bon.
class KeleganceClientResolu {
  const KeleganceClientResolu({
    required this.uid,
    required this.email,
    required this.nom,
    this.role,
    this.source,
  });

  final String uid;
  final String email;
  final String nom;
  final String? role;
  final String? source;
}

/// Aucun profil client pour l'e-mail saisi.
class KeleganceClientIntrouvableException implements Exception {
  KeleganceClientIntrouvableException(this.email);

  final String email;

  @override
  String toString() =>
      'Aucun client enregistré pour « $email ». Vérifiez l\'adresse ou créez le profil client.';
}

class KeleganceBonsCommandeSnapshot {
  const KeleganceBonsCommandeSnapshot({
    required this.docs,
    required this.changes,
    required this.premierChargement,
    required this.recuLe,
    required this.accesComplet,
  });

  final List<QueryDocumentSnapshot> docs;
  final List<DocumentChange> changes;
  final bool premierChargement;
  final DateTime recuLe;
  final bool accesComplet;
}

/// Gestion live des bons de commande retour — collection `bons_commande`.
abstract final class KeleganceBonCommandeService {
  static const String statutInitial = 'En attente';
  static const String typeDocument = 'bon_commande_retour';

  static final CollectionReference collection =
      FirebaseFirestore.instance.collection('bons_commande');

  static final ValueNotifier<DateTime?> derniereMiseAJour = ValueNotifier(null);

  static final StreamController<KeleganceBonsCommandeSnapshot> _flux =
      StreamController<KeleganceBonsCommandeSnapshot>.broadcast();

  static StreamSubscription<QuerySnapshot>? _abonnementFirestore;
  static bool _premierChargement = true;
  static bool _accesComplet = false;
  static String? _emailSession;
  static String? _uidSession;
  static KeleganceBonsCommandeSnapshot? _cache;

  static Stream<KeleganceBonsCommandeSnapshot> get flux => _flux.stream;

  static KeleganceBonsCommandeSnapshot? get cache => _cache;

  static bool get actif => _abonnementFirestore != null;

  static bool peutVoirTousLesBons([String? email]) => KeleganceRoles.estBrasDroit(email);

  /// Chauffeur ou Bras Droit — création autorisée.
  static Future<bool> utilisateurPeutCreer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final session = await AuthService.chargerRoleSession();
    return session == 'chauffeur' || KeleganceRoles.estBrasDroit();
  }

  static Future<void> demarrerPourUtilisateur(User user) async {
    await arreter();

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;

    await KeleganceRoles.initialiserPourUtilisateurCourant();
    final session = await AuthService.chargerRoleSession();
    _accesComplet = KeleganceRoles.estBrasDroit(email);
    _emailSession = email;
    _uidSession = user.uid;

    if (!_accesComplet && session != 'client' && session != 'chauffeur') {
      return;
    }

    _premierChargement = true;

    final Stream<QuerySnapshot> source;
    if (_accesComplet) {
      source = collection.snapshots();
    } else if (session == 'client') {
      source = collection.where('clientEmail', isEqualTo: email).snapshots();
    } else {
      source = collection.where('auteurUid', isEqualTo: user.uid).snapshots();
    }

    _abonnementFirestore = source.listen(
      (snap) {
        final docs = _filtrerDocuments(snap.docs);
        final instantane = KeleganceBonsCommandeSnapshot(
          docs: docs,
          changes: snap.docChanges,
          premierChargement: _premierChargement,
          recuLe: DateTime.now(),
          accesComplet: _accesComplet,
        );
        _premierChargement = false;
        _cache = instantane;
        derniereMiseAJour.value = instantane.recuLe;
        if (!_flux.isClosed) {
          _flux.add(instantane);
        }
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('KeleganceBonCommandeService: $e');
      },
    );

    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute bons_commande démarrée');
    }
  }

  static Future<void> arreter() async {
    await _abonnementFirestore?.cancel();
    _abonnementFirestore = null;
    _premierChargement = true;
    _accesComplet = false;
    _emailSession = null;
    _uidSession = null;
    _cache = null;
    derniereMiseAJour.value = null;
  }

  static List<QueryDocumentSnapshot> _filtrerDocuments(List<QueryDocumentSnapshot> docs) {
    if (_accesComplet) return List<QueryDocumentSnapshot>.from(docs);
    final mail = _emailSession;
    final uid = _uidSession;
    if (mail == null && uid == null) return const [];

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return peutVoirBon(data, email: mail, uid: uid);
    }).toList();
  }

  static bool peutVoirBon(Map<String, dynamic> data, {String? email, String? uid}) {
    if (KeleganceRoles.estBrasDroit(email)) return true;

    final mail = email?.trim().toLowerCase();
    final clientEmail = data['clientEmail']?.toString().trim().toLowerCase();
    final clientId = data['clientId']?.toString();
    final auteurUid = data['auteurUid']?.toString();

    if (uid != null && (clientId == uid || auteurUid == uid)) return true;
    if (mail != null && mail.isNotEmpty && clientEmail == mail) return true;
    return false;
  }

  static final RegExp _emailValide = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  static String? normaliserEmailClient(String? raw) {
    final mail = raw?.trim().toLowerCase();
    if (mail == null || mail.isEmpty || !_emailValide.hasMatch(mail)) return null;
    return mail;
  }

  static String extraireNomAffichage(Map<String, dynamic> data) {
    final prenom = data['prenom']?.toString().trim() ?? '';
    final nom = data['nom']?.toString().trim() ?? '';
    if (prenom.isNotEmpty || nom.isNotEmpty) return '$prenom $nom'.trim();
    for (final cle in ['fullName', 'name', 'displayName', 'clientNom']) {
      final v = data[cle]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return data['email']?.toString() ?? 'Client';
  }

  static bool _estRoleClient(String? role) {
    final r = role?.toLowerCase().trim().replaceAll(' ', '_') ?? '';
    return r.isEmpty || r == 'client' || r == 'passager';
  }

  static bool _estRoleExclu(String? role) {
    final r = role?.toLowerCase().trim().replaceAll(' ', '_') ?? '';
    return r == 'chauffeur' ||
        r == 'driver' ||
        r == 'conducteur' ||
        r == 'admin' ||
        r == 'administrateur' ||
        r == 'bras_droit';
  }

  /// Interroge `users` puis `clients` — retourne le profil client ou `null`.
  static Future<KeleganceClientResolu?> rechercherClientParEmail(String email) async {
    final mail = normaliserEmailClient(email);
    if (mail == null) return null;

    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: mail)
          .limit(12)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? candidatClient;
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final role = data['role']?.toString();
        if (_estRoleExclu(role)) continue;
        if (_estRoleClient(role)) {
          candidatClient = doc;
          break;
        }
        candidatClient ??= doc;
      }

      if (candidatClient != null) {
        final data = candidatClient.data();
        return KeleganceClientResolu(
          uid: candidatClient.id,
          email: mail,
          nom: extraireNomAffichage(data),
          role: data['role']?.toString(),
          source: 'users',
        );
      }

      final clientsSnap = await FirebaseFirestore.instance
          .collection('clients')
          .where('email', isEqualTo: mail)
          .limit(1)
          .get();

      if (clientsSnap.docs.isNotEmpty) {
        final doc = clientsSnap.docs.first;
        final data = doc.data();
        return KeleganceClientResolu(
          uid: doc.id,
          email: mail,
          nom: extraireNomAffichage(data),
          role: data['role']?.toString() ?? 'client',
          source: 'clients',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance recherche client: $e');
      rethrow;
    }

    return null;
  }

  /// Résout et valide le client — lève [KeleganceClientIntrouvableException] si absent.
  static Future<KeleganceClientResolu> resoudreClientObligatoire(String email) async {
    final mail = normaliserEmailClient(email);
    if (mail == null) {
      throw ArgumentError('Adresse e-mail client invalide.');
    }
    final client = await rechercherClientParEmail(mail);
    if (client == null) {
      throw KeleganceClientIntrouvableException(mail);
    }
    return client;
  }

  static Future<String> creer(KeleganceBonCommandeRetour bon) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }
    if (!await utilisateurPeutCreer()) {
      throw StateError('Droits insuffisants pour créer un bon de commande retour');
    }

    final emailSaisi = bon.clientEmail ?? '';
    final client = await resoudreClientObligatoire(emailSaisi);

    final clientNom = bon.clientNom.trim().isNotEmpty ? bon.clientNom.trim() : client.nom;
    final emailClient = client.email;
    final clientId = client.uid;

    final payload = <String, dynamic>{
      'type': typeDocument,
      'clientNom': clientNom,
      'clientEmail': emailClient,
      'clientId': clientId,
      'clientSource': client.source,
      'dateTransfert': _formaterDate(bon.dateTransfert),
      'dateTransfertTs': Timestamp.fromDate(bon.dateTransfert),
      'destination': bon.destination.trim(),
      'montant': bon.montant,
      'montantAffiche': '${bon.montant.toStringAsFixed(2)} €',
      'statut': bon.statut.trim().isEmpty ? statutInitial : bon.statut.trim(),
      'auteurUid': user.uid,
      'auteurEmail': user.email?.toLowerCase().trim(),
      'auteurNom': user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'kelegance_console_v1',
    };

    final ref = await collection.add(payload);
    if (kDebugMode) {
      debugPrint('Kelegance bon de commande retour créé: ${ref.id}');
    }
    return ref.id;
  }

  static String _formaterDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static List<QueryDocumentSnapshot> trierParDateRecente(List<QueryDocumentSnapshot> docs) {
    final copy = List<QueryDocumentSnapshot>.from(docs);
    copy.sort((a, b) {
      final da = _extraireDate(a.data() as Map<String, dynamic>);
      final db = _extraireDate(b.data() as Map<String, dynamic>);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return copy;
  }

  static DateTime? _extraireDate(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    final tsTransfert = data['dateTransfertTs'];
    if (tsTransfert is Timestamp) return tsTransfert.toDate();
    final brut = data['dateTransfert']?.toString() ?? '';
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(brut);
    if (match != null) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
    return null;
  }

  static ({String libelle, Color couleur}) presenterStatut(String? statut) {
    final s = (statut ?? '').toLowerCase().trim();
    if (s.contains('valid') || s.contains('confirm')) {
      return (libelle: 'Validé', couleur: Colors.greenAccent);
    }
    if (s.contains('annul') || s.contains('refus')) {
      return (libelle: 'Annulé', couleur: Colors.redAccent);
    }
    return (libelle: 'En attente', couleur: Colors.orangeAccent);
  }

  static double parserMontant(Map<String, dynamic> data) {
    final raw = data['montant'];
    if (raw is num) return raw.toDouble();
    final texte = raw?.toString().replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.') ?? '';
    return double.tryParse(texte) ?? 0;
  }
}

/// StreamBuilder bons de commande retour.
class KeleganceBonsCommandeStreamBuilder extends StatefulWidget {
  const KeleganceBonsCommandeStreamBuilder({
    super.key,
    required this.builder,
    this.filtre,
    this.afficherIndicateurLive = true,
  });

  final Widget Function(
    BuildContext context,
    KeleganceBonsCommandeSnapshot? snapshot,
    bool indicateurLiveVisible,
  ) builder;

  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot> docs)? filtre;

  final bool afficherIndicateurLive;

  @override
  State<KeleganceBonsCommandeStreamBuilder> createState() => _KeleganceBonsCommandeStreamBuilderState();
}

class _KeleganceBonsCommandeStreamBuilderState extends State<KeleganceBonsCommandeStreamBuilder> {
  bool _indicateurLiveVisible = false;
  Timer? _masquerIndicateur;

  @override
  void initState() {
    super.initState();
    KeleganceBonCommandeService.derniereMiseAJour.addListener(_surMiseAJourLive);
  }

  @override
  void dispose() {
    KeleganceBonCommandeService.derniereMiseAJour.removeListener(_surMiseAJourLive);
    _masquerIndicateur?.cancel();
    super.dispose();
  }

  void _surMiseAJourLive() {
    if (!mounted || !widget.afficherIndicateurLive) return;
    if (KeleganceBonCommandeService.derniereMiseAJour.value == null) return;

    _masquerIndicateur?.cancel();
    setState(() => _indicateurLiveVisible = true);
    _masquerIndicateur = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _indicateurLiveVisible = false);
    });
  }

  KeleganceBonsCommandeSnapshot? _appliquerFiltre(KeleganceBonsCommandeSnapshot? source) {
    if (source == null || widget.filtre == null) return source;
    final docs = widget.filtre!(source.docs);
    return KeleganceBonsCommandeSnapshot(
      docs: docs,
      changes: source.changes,
      premierChargement: source.premierChargement,
      recuLe: source.recuLe,
      accesComplet: source.accesComplet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KeleganceBonsCommandeSnapshot>(
      stream: KeleganceBonCommandeService.flux,
      initialData: KeleganceBonCommandeService.cache,
      builder: (context, snapshot) {
        final data = _appliquerFiltre(snapshot.data);
        final enAttente =
            snapshot.connectionState == ConnectionState.waiting && data == null;

        if (enAttente) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        if (!KeleganceBonCommandeService.actif) {
          return Center(
            child: Text(
              'Historique des bons indisponible.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.builder(context, data, _indicateurLiveVisible),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _indicateurLiveVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.15),
                          Colors.amber,
                          Colors.amber.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
