import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Instantané live d'une écoute Firestore sur `missions`.
class KeleganceMissionsSnapshot {
  const KeleganceMissionsSnapshot({
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

/// Couche données « Live Update » — une seule souscription Firestore partagée.
abstract final class KeleganceMissionsService {
  static final CollectionReference collection =
      FirebaseFirestore.instance.collection('missions');

  static final ValueNotifier<DateTime?> derniereMiseAJour = ValueNotifier(null);

  static final StreamController<KeleganceMissionsSnapshot> _flux =
      StreamController<KeleganceMissionsSnapshot>.broadcast();

  static StreamSubscription<QuerySnapshot>? _abonnementFirestore;
  static bool _premierChargement = true;
  static KeleganceMissionsSnapshot? _cache;

  static Stream<KeleganceMissionsSnapshot> get flux => _flux.stream;

  static KeleganceMissionsSnapshot? get cache => _cache;

  static bool get actif => _abonnementFirestore != null;

  static void demarrer() {
    if (_abonnementFirestore != null) return;

    _premierChargement = true;
    _abonnementFirestore = collection.snapshots().listen(
      (snap) {
        final instantane = KeleganceMissionsSnapshot(
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
        if (kDebugMode) debugPrint('KeleganceMissionsService: $e');
      },
    );

    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute missions démarrée');
    }
  }

  static Future<void> arreter() async {
    await _abonnementFirestore?.cancel();
    _abonnementFirestore = null;
    _premierChargement = true;
    _cache = null;
    derniereMiseAJour.value = null;
    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute missions arrêtée');
    }
  }

  static List<QueryDocumentSnapshot> missionsClient(String? email) {
    final mail = email?.trim();
    if (mail == null || mail.isEmpty) return const [];
    return (_cache?.docs ?? [])
        .where((doc) => (doc.data() as Map<String, dynamic>)['client'] == mail)
        .toList();
  }

  static QueryDocumentSnapshot? missionParId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final doc in _cache?.docs ?? const <QueryDocumentSnapshot>[]) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  /// Mappe un statut Firestore vers l'étape console chauffeur.
  static String? etapeDepuisStatut(String? statut) {
    final s = (statut ?? '').toUpperCase().replaceAll('É', 'E').trim();
    if (s.contains('EN ROUTE') || s == 'EN_ROUTE') return 'EN_ROUTE';
    if (s.contains('SUR PLACE')) return 'SUR_PLACE';
    if (s.contains('EN COURSE')) return 'EN_COURSE';
    if (s.contains('TERMINE') || s.contains('ANNUL')) return 'AUCUNE';
    return null;
  }

  static bool statutCourseActive(String? statut) {
    final etape = etapeDepuisStatut(statut);
    return etape != null && etape != 'AUCUNE';
  }
}

/// StreamBuilder missions avec indicateur visuel lors des mises à jour live.
class KeleganceMissionsStreamBuilder extends StatefulWidget {
  const KeleganceMissionsStreamBuilder({
    super.key,
    required this.builder,
    this.filtre,
    this.afficherIndicateurLive = true,
  });

  final Widget Function(
    BuildContext context,
    KeleganceMissionsSnapshot? snapshot,
    bool indicateurLiveVisible,
  ) builder;

  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot> docs)? filtre;

  final bool afficherIndicateurLive;

  @override
  State<KeleganceMissionsStreamBuilder> createState() => _KeleganceMissionsStreamBuilderState();
}

class _KeleganceMissionsStreamBuilderState extends State<KeleganceMissionsStreamBuilder> {
  bool _indicateurLiveVisible = false;
  Timer? _masquerIndicateur;

  @override
  void initState() {
    super.initState();
    KeleganceMissionsService.derniereMiseAJour.addListener(_surMiseAJourLive);
  }

  @override
  void dispose() {
    KeleganceMissionsService.derniereMiseAJour.removeListener(_surMiseAJourLive);
    _masquerIndicateur?.cancel();
    super.dispose();
  }

  void _surMiseAJourLive() {
    if (!mounted || !widget.afficherIndicateurLive) return;
    final ts = KeleganceMissionsService.derniereMiseAJour.value;
    if (ts == null) return;

    _masquerIndicateur?.cancel();
    setState(() => _indicateurLiveVisible = true);
    _masquerIndicateur = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _indicateurLiveVisible = false);
    });
  }

  KeleganceMissionsSnapshot? _appliquerFiltre(KeleganceMissionsSnapshot? source) {
    if (source == null || widget.filtre == null) return source;
    final docs = widget.filtre!(source.docs);
    return KeleganceMissionsSnapshot(
      docs: docs,
      changes: source.changes,
      premierChargement: source.premierChargement,
      recuLe: source.recuLe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KeleganceMissionsSnapshot>(
      stream: KeleganceMissionsService.flux,
      initialData: KeleganceMissionsService.cache,
      builder: (context, snapshot) {
        final data = _appliquerFiltre(snapshot.data);
        final enAttente = snapshot.connectionState == ConnectionState.waiting &&
            data == null;

        if (enAttente) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
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
                          Colors.amber.withOpacity(0.1),
                          Colors.amber,
                          Colors.amber.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.35),
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
