import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'kelegance_roles.dart';

/// Instantané live d'une écoute Firestore sur `factures`.
class KeleganceFacturesSnapshot {
  const KeleganceFacturesSnapshot({
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

  /// `true` si l'utilisateur a accès Bras Droit (toutes les factures).
  final bool accesComplet;
}

/// Couche données live — factures client / admin, une seule souscription partagée.
abstract final class KeleganceFacturesService {
  static final CollectionReference collection =
      FirebaseFirestore.instance.collection('factures');

  static final ValueNotifier<DateTime?> derniereMiseAJour = ValueNotifier(null);

  static final StreamController<KeleganceFacturesSnapshot> _flux =
      StreamController<KeleganceFacturesSnapshot>.broadcast();

  static StreamSubscription<QuerySnapshot>? _abonnementFirestore;
  static bool _premierChargement = true;
  static bool _accesComplet = false;
  static KeleganceFacturesSnapshot? _cache;
  static String? _emailSession;

  static Stream<KeleganceFacturesSnapshot> get flux => _flux.stream;

  static KeleganceFacturesSnapshot? get cache => _cache;

  static bool get actif => _abonnementFirestore != null;

  static bool get accesCompletActif => _accesComplet && actif;

  /// Vue expert globale — Bras Droit / admin uniquement.
  static bool peutAccederVueGlobale([String? email]) => KeleganceRoles.estBrasDroit(email);

  /// Bras Droit : flux global. Client : filtre Firestore par e-mail. Chauffeur : aucun flux.
  static Future<void> demarrerPourUtilisateur(User user) async {
    await arreter();

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;

    await KeleganceRoles.initialiserPourUtilisateurCourant();
    final session = await AuthService.chargerRoleSession();
    _accesComplet = KeleganceRoles.estBrasDroit(email);
    _emailSession = email;

    if (!_accesComplet && session == 'chauffeur') {
      if (kDebugMode) {
        debugPrint('Kelegance Live factures — accès refusé (chauffeur sans Bras Droit)');
      }
      return;
    }

    _premierChargement = true;

    final Stream<QuerySnapshot> source = _accesComplet
        ? collection.snapshots()
        : collection.where('client', isEqualTo: user.email).snapshots();

    _abonnementFirestore = source.listen(
      (snap) {
        final docs = _filtrerDocuments(snap.docs);
        final instantane = KeleganceFacturesSnapshot(
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
        if (kDebugMode) debugPrint('KeleganceFacturesService: $e');
      },
    );

    if (kDebugMode) {
      debugPrint(
        _accesComplet
            ? 'Kelegance Live — écoute factures (accès complet)'
            : 'Kelegance Live — écoute factures client ($email)',
      );
    }
  }

  static Future<void> arreter() async {
    await _abonnementFirestore?.cancel();
    _abonnementFirestore = null;
    _premierChargement = true;
    _accesComplet = false;
    _emailSession = null;
    _cache = null;
    derniereMiseAJour.value = null;
    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute factures arrêtée');
    }
  }

  /// Filtre défensif côté client — ne conserve que les factures autorisées.
  static List<QueryDocumentSnapshot> _filtrerDocuments(List<QueryDocumentSnapshot> docs) {
    if (_accesComplet) return List<QueryDocumentSnapshot>.from(docs);
    final mail = _emailSession;
    if (mail == null) return const [];

    return docs.where((doc) => peutVoirFacture(doc.data() as Map<String, dynamic>, email: mail)).toList();
  }

  static bool peutVoirFacture(Map<String, dynamic> data, {String? email}) {
    if (KeleganceRoles.estBrasDroit(email)) return true;

    final mail = email?.trim().toLowerCase();
    if (mail == null || mail.isEmpty) return false;

    final client = data['client']?.toString().trim().toLowerCase();
    final factureEmail = data['email']?.toString().trim().toLowerCase();
    return client == mail || factureEmail == mail;
  }

  static List<QueryDocumentSnapshot> trierParDateRecente(List<QueryDocumentSnapshot> docs) {
    final copy = List<QueryDocumentSnapshot>.from(docs);
    copy.sort((a, b) {
      final da = _parserDateFacture(a.data() as Map<String, dynamic>);
      final db = _parserDateFacture(b.data() as Map<String, dynamic>);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return copy;
  }

  static DateTime? _parserDateFacture(Map<String, dynamic> data) {
    final brut = data['date']?.toString().trim() ?? '';
    if (brut.isEmpty) return null;

    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(brut);
    if (slash != null) {
      return DateTime(
        int.parse(slash.group(3)!),
        int.parse(slash.group(2)!),
        int.parse(slash.group(1)!),
      );
    }

    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.tryParse(brut);
  }

  static ({String libelle, Color couleur}) presenterStatut(String? statut) {
    final s = (statut ?? '').toUpperCase().replaceAll('É', 'E').trim();
    if (s.contains('PAYE') || s == 'PAID' || s.contains('REGLE')) {
      return (libelle: 'Payée', couleur: Colors.greenAccent);
    }
    if (s.contains('ATTENTE') || s == 'PENDING' || s.contains('EN_COURS')) {
      return (libelle: 'En attente', couleur: Colors.orangeAccent);
    }
    if (s.contains('PUBLIE') || s.contains('PUBLI') || s.contains('EMIS')) {
      return (libelle: 'Publiée', couleur: Colors.lightBlueAccent);
    }
    if (s.contains('ANNULE') || s.contains('REFUS')) {
      return (libelle: 'Annulée', couleur: Colors.redAccent);
    }
    if (statut == null || statut.trim().isEmpty) {
      return (libelle: 'En attente', couleur: Colors.orangeAccent);
    }
    return (libelle: statut, couleur: Colors.white54);
  }

  static double parserMontant(dynamic raw) {
    if (raw is num) return raw.toDouble();
    final texte = raw?.toString().replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.') ?? '';
    return double.tryParse(texte) ?? 0;
  }

  /// Totaux financiers live — Payé vs En attente.
  static ({
    double totalPaye,
    double totalEnAttente,
    int nbPayees,
    int nbEnAttente,
  }) calculerTotauxDashboard(List<QueryDocumentSnapshot> docs) {
    var totalPaye = 0.0;
    var totalEnAttente = 0.0;
    var nbPayees = 0;
    var nbEnAttente = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final montant = parserMontant(data['montant']);
      final statut = presenterStatut(data['statut']?.toString());

      if (statut.libelle == 'Payée') {
        totalPaye += montant;
        nbPayees++;
      } else if (statut.libelle == 'En attente') {
        totalEnAttente += montant;
        nbEnAttente++;
      }
    }

    return (
      totalPaye: totalPaye,
      totalEnAttente: totalEnAttente,
      nbPayees: nbPayees,
      nbEnAttente: nbEnAttente,
    );
  }
}

/// StreamBuilder factures avec barre de synchronisation live.
class KeleganceFacturesStreamBuilder extends StatefulWidget {
  const KeleganceFacturesStreamBuilder({
    super.key,
    required this.builder,
    this.filtre,
    this.afficherIndicateurLive = true,
  });

  final Widget Function(
    BuildContext context,
    KeleganceFacturesSnapshot? snapshot,
    bool indicateurLiveVisible,
  ) builder;

  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot> docs)? filtre;

  final bool afficherIndicateurLive;

  @override
  State<KeleganceFacturesStreamBuilder> createState() => _KeleganceFacturesStreamBuilderState();
}

class _KeleganceFacturesStreamBuilderState extends State<KeleganceFacturesStreamBuilder> {
  bool _indicateurLiveVisible = false;
  Timer? _masquerIndicateur;

  @override
  void initState() {
    super.initState();
    KeleganceFacturesService.derniereMiseAJour.addListener(_surMiseAJourLive);
  }

  @override
  void dispose() {
    KeleganceFacturesService.derniereMiseAJour.removeListener(_surMiseAJourLive);
    _masquerIndicateur?.cancel();
    super.dispose();
  }

  void _surMiseAJourLive() {
    if (!mounted || !widget.afficherIndicateurLive) return;
    if (KeleganceFacturesService.derniereMiseAJour.value == null) return;

    _masquerIndicateur?.cancel();
    setState(() => _indicateurLiveVisible = true);
    _masquerIndicateur = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _indicateurLiveVisible = false);
    });
  }

  KeleganceFacturesSnapshot? _appliquerFiltre(KeleganceFacturesSnapshot? source) {
    if (source == null || widget.filtre == null) return source;
    final docs = widget.filtre!(source.docs);
    return KeleganceFacturesSnapshot(
      docs: docs,
      changes: source.changes,
      premierChargement: source.premierChargement,
      recuLe: source.recuLe,
      accesComplet: source.accesComplet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KeleganceFacturesSnapshot>(
      stream: KeleganceFacturesService.flux,
      initialData: KeleganceFacturesService.cache,
      builder: (context, snapshot) {
        final data = _appliquerFiltre(snapshot.data);
        final enAttente =
            snapshot.connectionState == ConnectionState.waiting && data == null;

        if (enAttente) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        if (!KeleganceFacturesService.actif) {
          return Center(
            child: Text(
              'Documents financiers non disponibles pour ce profil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
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
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.15),
                          const Color(0xFF66BB6A),
                          const Color(0xFF4CAF50).withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF66BB6A).withOpacity(0.35),
                          blurRadius: 6,
                        ),
                      ],
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
