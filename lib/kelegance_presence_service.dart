import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kelegance_roles.dart';

/// Instantané live d'une écoute Firestore sur `presence`.
class KelegancePresenceSnapshot {
  const KelegancePresenceSnapshot({
    required this.docs,
    required this.changes,
    required this.premierChargement,
    required this.recuLe,
  });

  final List<QueryDocumentSnapshot> docs;
  final List<DocumentChange> changes;
  final bool premierChargement;
  final DateTime recuLe;
}

/// Présence équipe — écriture + flux live (modèle missions / factures).
abstract final class KelegancePresenceService {
  static final CollectionReference collection =
      FirebaseFirestore.instance.collection('presence');

  static final ValueNotifier<DateTime?> derniereMiseAJour = ValueNotifier(null);

  static final StreamController<KelegancePresenceSnapshot> _flux =
      StreamController<KelegancePresenceSnapshot>.broadcast();

  static StreamSubscription<QuerySnapshot>? _abonnementFirestore;
  static bool _premierChargement = true;
  static KelegancePresenceSnapshot? _cache;

  static Stream<KelegancePresenceSnapshot> get flux => _flux.stream;

  static KelegancePresenceSnapshot? get cache => _cache;

  static bool get actif => _abonnementFirestore != null;

  /// Liste complète — Bras Droit / admin uniquement.
  static bool peutVoirListeComplete([String? email]) => KeleganceRoles.estBrasDroit(email);

  static String calculerStatut({required bool enLigne, required bool enCourse}) {
    if (!enLigne) return 'hors_ligne';
    if (enCourse) return 'en_course';
    return 'disponible';
  }

  static ({String libelle, Color couleur}) presenterStatut(
    Map<String, dynamic> data,
  ) {
    final brut = data['statut']?.toString().toLowerCase().trim();
    final enLigne = data['enLigne'] == true;
    final enCourse = data['enCourse'] == true;
    final statut = brut?.isNotEmpty == true
        ? brut!
        : calculerStatut(enLigne: enLigne, enCourse: enCourse);

    switch (statut) {
      case 'disponible':
        return (libelle: 'Disponible', couleur: Colors.greenAccent);
      case 'en_service':
        return (libelle: 'En service', couleur: Colors.lightGreenAccent);
      case 'en_course':
        return (libelle: 'En course', couleur: Colors.orangeAccent);
      case 'hors_ligne':
      default:
        return (libelle: 'Hors ligne', couleur: Colors.grey);
    }
  }

  static bool estCollaborateurVisible(Map<String, dynamic> data, {String? monUid, String? docId}) {
    if (docId != null && docId == monUid) return false;
    final email = data['email']?.toString();
    if (KeleganceRoles.profilIndiqueBrasDroit(data) || KeleganceRoles.estBrasDroit(email)) {
      return false;
    }
    return true;
  }

  static List<QueryDocumentSnapshot> collaborateursVisibles(
    List<QueryDocumentSnapshot> docs, {
    String? monUid,
    bool actifsSeulement = false,
  }) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!estCollaborateurVisible(data, monUid: monUid, docId: doc.id)) return false;
      if (!actifsSeulement) return true;
      final statut = presenterStatut(data);
      return statut.libelle != 'Hors ligne';
    }).toList();
  }

  /// Écoute globale — réservée aux profils Bras Droit.
  static Future<void> demarrerEcoutePourUtilisateur(User user) async {
    await arreter();

    await KeleganceRoles.initialiserPourUtilisateurCourant();
    if (!peutVoirListeComplete(user.email)) return;

    _premierChargement = true;
    _abonnementFirestore = collection.snapshots().listen(
      (snap) {
        final instantane = KelegancePresenceSnapshot(
          docs: snap.docs,
          changes: snap.docChanges,
          premierChargement: _premierChargement,
          recuLe: DateTime.now(),
        );
        _premierChargement = false;
        _cache = instantane;
        derniereMiseAJour.value = instantane.recuLe;
        if (!_flux.isClosed) {
          _flux.add(instantane);
        }
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('KelegancePresenceService live: $e');
      },
    );

    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute présence équipe démarrée');
    }
  }

  static Future<void> arreter() async {
    await _abonnementFirestore?.cancel();
    _abonnementFirestore = null;
    _premierChargement = true;
    _cache = null;
    derniereMiseAJour.value = null;
    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute présence arrêtée');
    }
  }

  /// Publie l'état courant vers `presence` (+ miroir `chauffeurs` pour dispatch).
  static Future<void> publier({
    required bool enLigne,
    required bool enCourse,
    String? nom,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final statut = calculerStatut(enLigne: enLigne, enCourse: enCourse);
    final email = user.email?.toLowerCase().trim();
    final payload = <String, dynamic>{
      'email': email,
      if (nom != null && nom.trim().isNotEmpty) 'name': nom.trim(),
      'enLigne': enLigne,
      'enCourse': enCourse,
      'statut': statut,
      'role': 'chauffeur',
      'derniereActivite': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await collection.doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(
        {
          'email': email,
          if (nom != null && nom.trim().isNotEmpty) 'name': nom.trim(),
          'enLigne': enLigne,
          'enCourse': enCourse,
          'statut': statut,
          'role': 'chauffeur',
          'derniereActivite': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance présence: $e');
    }
  }

  /// Déconnexion — force « Hors ligne » avant fermeture de session.
  static Future<void> declarerHorsLigne() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final email = user.email?.toLowerCase().trim();
      final payload = <String, dynamic>{
        'email': email,
        'enLigne': false,
        'enCourse': false,
        'statut': 'hors_ligne',
        'derniereActivite': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await collection.doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(
        payload,
        SetOptions(merge: true),
      );
      if (kDebugMode) {
        debugPrint('Kelegance présence — hors ligne avant déconnexion');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance présence hors ligne: $e');
    }
  }

  static Future<bool?> chargerEnLigne() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final docPresence = await collection.doc(user.uid).get();
      final presence = docPresence.data();
      if (presence is Map<String, dynamic>) return presence['enLigne'] == true;

      final docChauffeur =
          await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get();
      final data = docChauffeur.data();
      if (data == null) return null;
      return data['enLigne'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance présence lecture: $e');
      return null;
    }
  }
}

/// StreamBuilder présence avec indicateur live.
class KelegancePresenceStreamBuilder extends StatefulWidget {
  const KelegancePresenceStreamBuilder({
    super.key,
    required this.builder,
    this.filtre,
    this.afficherIndicateurLive = true,
  });

  final Widget Function(
    BuildContext context,
    KelegancePresenceSnapshot? snapshot,
    bool indicateurLiveVisible,
  ) builder;

  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot> docs)? filtre;

  final bool afficherIndicateurLive;

  @override
  State<KelegancePresenceStreamBuilder> createState() => _KelegancePresenceStreamBuilderState();
}

class _KelegancePresenceStreamBuilderState extends State<KelegancePresenceStreamBuilder> {
  bool _indicateurLiveVisible = false;
  Timer? _masquerIndicateur;

  @override
  void initState() {
    super.initState();
    KelegancePresenceService.derniereMiseAJour.addListener(_surMiseAJourLive);
  }

  @override
  void dispose() {
    KelegancePresenceService.derniereMiseAJour.removeListener(_surMiseAJourLive);
    _masquerIndicateur?.cancel();
    super.dispose();
  }

  void _surMiseAJourLive() {
    if (!mounted || !widget.afficherIndicateurLive) return;
    if (KelegancePresenceService.derniereMiseAJour.value == null) return;

    _masquerIndicateur?.cancel();
    setState(() => _indicateurLiveVisible = true);
    _masquerIndicateur = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _indicateurLiveVisible = false);
    });
  }

  KelegancePresenceSnapshot? _appliquerFiltre(KelegancePresenceSnapshot? source) {
    if (source == null || widget.filtre == null) return source;
    final docs = widget.filtre!(source.docs);
    return KelegancePresenceSnapshot(
      docs: docs,
      changes: source.changes,
      premierChargement: source.premierChargement,
      recuLe: source.recuLe,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!KelegancePresenceService.peutVoirListeComplete()) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<KelegancePresenceSnapshot>(
      stream: KelegancePresenceService.flux,
      initialData: KelegancePresenceService.cache,
      builder: (context, snapshot) {
        final data = _appliquerFiltre(snapshot.data);
        final enAttente =
            snapshot.connectionState == ConnectionState.waiting && data == null;

        if (enAttente) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
              ),
            ),
          );
        }

        if (!KelegancePresenceService.actif) {
          return const SizedBox.shrink();
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.builder(context, data, _indicateurLiveVisible),
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _indicateurLiveVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyanAccent.withOpacity(0.1),
                          Colors.cyanAccent,
                          Colors.cyanAccent.withOpacity(0.1),
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
