import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kelegance_firestore_live.dart';
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

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _abonnementFirestore;
  static bool _premierChargement = true;
  static KelegancePresenceSnapshot? _cache;
  static String? _uidEcouteActif;
  static bool _publishEnCours = false;
  static bool? _lastEnLignePublie;
  static bool? _lastEnCoursePublie;
  static DateTime? _lastPublishAt;
  static const Duration _antiRebondPublish = Duration(milliseconds: 1800);
  static final Map<String, DateTime> _dernierVuEnLigne = {};
  static const Duration _graceHorsLigne = Duration(seconds: 10);

  static Stream<KelegancePresenceSnapshot> get flux => _flux.stream;

  static KelegancePresenceSnapshot? get cache => _cache;

  static bool get actif => _abonnementFirestore != null;

  /// Écoute présence équipe — tout chauffeur authentifié.
  static bool peutEcouterPresenceEquipe([String? email]) {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Liste complète avec dispatch — Bras Droit / admin.
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

  static bool estEnLigne(Map<String, dynamic> data) {
    if (data['enLigne'] == true) return true;
    final statut = data['statut']?.toString().toLowerCase().trim();
    return statut == 'disponible' || statut == 'en_service' || statut == 'en_course';
  }

  /// Évite le clignotement liste équipe — garde visible 10 s après dernière vue en ligne.
  static bool estEnLigneStable(String docId, Map<String, dynamic> data) {
    if (estEnLigne(data)) {
      _dernierVuEnLigne[docId] = DateTime.now();
      return true;
    }
    final vu = _dernierVuEnLigne[docId];
    if (vu != null && DateTime.now().difference(vu) < _graceHorsLigne) {
      return true;
    }
    return false;
  }

  /// Membres équipe visibles — tous les profils en ligne sauf soi (sans filtre rôle).
  static List<QueryDocumentSnapshot> membresEquipeVisibles(
    List<QueryDocumentSnapshot> docs, {
    String? monUid,
    bool enLigneSeulement = true,
  }) {
    final journal = <String>[];
    final result = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final nom = data['name'] ?? data['email'] ?? doc.id;
      if (monUid != null && doc.id == monUid) {
        journal.add('⊘ $nom (moi)');
        return false;
      }
      if (enLigneSeulement && !estEnLigneStable(doc.id, data)) {
        journal.add('⊘ $nom hors ligne');
        return false;
      }
      journal.add('✓ $nom enLigne=${data['enLigne']}');
      return true;
    }).toList();

    logEquipe(
      'membresEquipeVisibles — brut=${docs.length} affichés=${result.length} '
      'monUid=$monUid enLigneSeulement=$enLigneSeulement\n${journal.join('\n')}',
    );
    return result;
  }

  /// Journal équipe — visible en logcat release (`adb logcat -s KeleganceEquipe`).
  static void logEquipe(String message) {
    if (kDebugMode) debugPrint('KeleganceEquipe — $message');
    // ignore: avoid_print
    print('KeleganceEquipe — $message');
  }

  /// Écoute globale `presence` — idempotent (ne coupe pas le flux si déjà actif pour ce uid).
  static Future<void> demarrerEcoutePourUtilisateur(User user) async {
    if (_abonnementFirestore != null && _uidEcouteActif == user.uid) {
      return;
    }

    await arreter();

    await KeleganceRoles.initialiserPourUtilisateurCourant();
    if (!peutEcouterPresenceEquipe(user.email)) {
      if (kDebugMode) {
        debugPrint('Kelegance Live — écoute présence ignorée (session absente)');
      }
      return;
    }

    _uidEcouteActif = user.uid;
    _premierChargement = true;
    // Flux léger — uniquement les collaborateurs en ligne (collection `presence` dédiée).
    final requete = collection
        .where('enLigne', isEqualTo: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        );
    _abonnementFirestore = KeleganceFirestoreLive.ecouterRequete(
      requete: requete,
      etiquette: 'presence',
      ignorerCacheSeul: true,
      onData: (snap) {
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
        if (kDebugMode) {
          debugPrint(
            'Kelegance Live — snapshot présence uid=${user.uid} docs=${snap.docs.length}',
          );
        }
        logEquipe(
          'stream brut uid=${user.uid} docs=${snap.docs.length} — '
          '${snap.docs.map((d) {
            final data = d.data();
            return '${d.id}:${data['name'] ?? data['email'] ?? "?"} enLigne=${data['enLigne']}';
          }).join(' | ')}',
        );
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.removed) continue;
          final data = change.doc.data();
          if (data == null) continue;
          logEquipe(
            'Δ ${change.type.name} doc=${change.doc.id} enLigne=${data['enLigne']} '
            'statut=${data['statut']}',
          );
        }
      },
      onError: (Object e) {
        logEquipe('ERREUR stream présence uid=${user.uid}: $e');
        if (kDebugMode) debugPrint('KelegancePresenceService live uid=${user.uid}: $e');
      },
    );

    if (kDebugMode) {
      debugPrint('Kelegance Live — écoute présence démarrée uid=${user.uid}');
    }
  }

  static Future<void> arreter() async {
    await _abonnementFirestore?.cancel();
    _abonnementFirestore = null;
    _uidEcouteActif = null;
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
    String source = 'app',
    bool forcer = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final basculeUtilisateur = source == 'toggle' || source == 'signout';
    if (!forcer && !basculeUtilisateur) {
      if (_lastEnLignePublie == enLigne &&
          _lastEnCoursePublie == enCourse &&
          _lastPublishAt != null &&
          now.difference(_lastPublishAt!) < _antiRebondPublish) {
        logEquipe('publier ignoré anti-rebond source=$source enLigne=$enLigne');
        return;
      }
    }
    if (_publishEnCours) {
      logEquipe('publier ignoré (écriture en cours) source=$source');
      return;
    }
    _publishEnCours = true;

    final statut = calculerStatut(enLigne: enLigne, enCourse: enCourse);
    final email = user.email?.toLowerCase().trim();
    // Document `presence` minimal — flux temps réel ultra-léger.
    final payload = <String, dynamic>{
      'email': email,
      if (nom != null && nom.trim().isNotEmpty) 'name': nom.trim(),
      'enLigne': enLigne,
      'enCourse': enCourse,
      'statut': statut,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      logEquipe(
        'publier → uid=${user.uid} source=$source enLigne=$enLigne enCourse=$enCourse statut=$statut',
      );
      await collection.doc(user.uid).set(payload, SetOptions(merge: true));
      // Miroir chauffeurs asynchrone — ne bloque pas le flux live.
      unawaited(_miroirChauffeurPresence(user.uid, email, nom, enLigne, enCourse, statut));
      _lastEnLignePublie = enLigne;
      _lastEnCoursePublie = enCourse;
      _lastPublishAt = now;
      if (enLigne) {
        _dernierVuEnLigne[user.uid] = now;
      } else {
        _dernierVuEnLigne.remove(user.uid);
      }
    } catch (e) {
      logEquipe('ERREUR publier uid=${user.uid} source=$source: $e');
      if (kDebugMode) debugPrint('Kelegance présence: $e');
    } finally {
      _publishEnCours = false;
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
        'updatedAt': FieldValue.serverTimestamp(),
      };
      logEquipe('declarerHorsLigne → uid=${user.uid}');
      await collection.doc(user.uid).set(payload, SetOptions(merge: true));
      unawaited(_miroirChauffeurPresence(user.uid, email, null, false, false, 'hors_ligne'));
      if (kDebugMode) {
        debugPrint('Kelegance présence — hors ligne avant déconnexion');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance présence hors ligne: $e');
    }
  }

  static Future<void> _miroirChauffeurPresence(
    String uid,
    String? email,
    String? nom,
    bool enLigne,
    bool enCourse,
    String statut,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('chauffeurs').doc(uid).set(
        {
          'email': email,
          if (nom != null && nom.trim().isNotEmpty) 'name': nom.trim(),
          'enLigne': enLigne,
          'enCourse': enCourse,
          'statut': statut,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      logEquipe('miroir chauffeurs uid=$uid: $e');
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !KelegancePresenceService.actif) {
      unawaited(KelegancePresenceService.demarrerEcoutePourUtilisateur(user));
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!KelegancePresenceService.peutEcouterPresenceEquipe()) {
      if (kDebugMode) debugPrint('KelegancePresenceStreamBuilder — session absente');
      return _messageEtat('Session requise pour la présence équipe.');
    }

    if (!KelegancePresenceService.actif) {
      if (kDebugMode) {
        debugPrint('KelegancePresenceStreamBuilder — écoute inactive uid=$uid, démarrage…');
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(KelegancePresenceService.demarrerEcoutePourUtilisateur(user));
      }
      return _messageEtat('Connexion à l\'équipe en cours…');
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
          return _messageEtat('Écoute présence interrompue — reconnexion…');
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

  Widget _messageEtat(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
