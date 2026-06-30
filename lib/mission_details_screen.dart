import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Feuille de route mission — console chauffeur (itinéraire, consignes, démarrage).
class MissionDetailsScreen extends StatefulWidget {
  const MissionDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    this.couleurAccent = const Color(0xFFD4AF37),
    this.fond = const Color(0xFF000000),
    this.onDemarrerCourse,
  });

  final String docId;
  final Map<String, dynamic> data;
  final Color couleurAccent;
  final Color fond;

  /// Si fourni (ex. [_prendreCourse] console), synchronise l'état local chauffeur.
  final Future<void> Function()? onDemarrerCourse;

  static String? destinationMission(Map<String, dynamic> data) {
    final destination = data['destination']?.toString().trim() ?? '';
    return destination.isEmpty ? null : destination;
  }

  static String? telephoneClient(Map<String, dynamic> data) {
    final direct = data['clientPhone']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final cle in ['phone', 'telephone', 'tel', 'mobile']) {
      final valeur = data[cle]?.toString().trim();
      if (valeur != null && valeur.isNotEmpty) return valeur;
    }
    return null;
  }

  static List<String> consignesSpeciales(Map<String, dynamic> data) {
    final vues = <String>{};
    for (final cle in ['consignes', 'instructions', 'instructionsSpeciales', 'note']) {
      final texte = data[cle]?.toString().trim();
      if (texte != null && texte.isNotEmpty) vues.add(texte);
    }
    return vues.toList();
  }

  static bool estMissionEnCours(String? statut) {
    final s = (statut ?? '').toUpperCase().replaceAll('É', 'E').replaceAll(' ', '_').trim();
    return s == 'EN_COURS' ||
        s == 'EN_COURSE' ||
        s == 'EN_ROUTE' ||
        s.contains('SUR_PLACE') ||
        s == 'ENCOURS';
  }

  static bool estMissionTerminee(String? statut) {
    final s = (statut ?? '').toUpperCase().replaceAll('É', 'E').trim();
    return s == 'TERMINE' || s == 'TERMINÉ' || s.contains('TERMIN');
  }

  static String _formaterDateRapport(String? brut) {
    final texte = brut?.trim() ?? '';
    if (texte.isEmpty) return '—';
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texte);
    if (slash != null) {
      final jour = slash.group(1)!.padLeft(2, '0');
      final mois = slash.group(2)!.padLeft(2, '0');
      return '$jour/$mois/${slash.group(3)}';
    }
    final iso = DateTime.tryParse(texte.split(' ').first);
    if (iso != null) {
      return '${iso.day.toString().padLeft(2, '0')}/${iso.month.toString().padLeft(2, '0')}/${iso.year}';
    }
    return texte;
  }

  static String _extraireHeureArrivee(Map<String, dynamic> data) {
    for (final cle in ['heureArrivee', 'heureFin', 'heure_arrivee']) {
      final v = data[cle]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final ts = data['courseTermineeAt'] ?? data['pipeline_updated_at'];
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  static String _extraireChauffeur(Map<String, dynamic> data) {
    for (final cle in ['chauffeurNom', 'chauffeurAssigne', 'chauffeur']) {
      final v = data[cle]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '—';
  }

  /// Template reporting client — variables : date, heures, depart, arrivee, chauffeur.
  static String construireRapportClient(Map<String, dynamic> data) {
    final date = _formaterDateRapport(data['date']?.toString());
    final heure = data['heure']?.toString().trim() ?? data['heure_depart']?.toString().trim() ?? '—';
    final heureArrivee = _extraireHeureArrivee(data);
    final depart = data['depart']?.toString().trim() ?? '—';
    final arrivee = data['destination']?.toString().trim() ??
        data['adresseArrivee']?.toString().trim() ??
        data['lieu_arrivee']?.toString().trim() ??
        '—';
    final chauffeur = _extraireChauffeur(data);

    return '''Bonjour,

Compte-rendu de course KELEGANCE

Date : $date
Heure de prise en charge : $heure
Départ : $depart
Arrivée : $arrivee
Heure d'arrivée : $heureArrivee
Chauffeur : $chauffeur

Bien cordialement,
KELEGANCE PRESTIGE''';
  }

  static Future<void> copierRapportClient(Map<String, dynamic> data) async {
    await Clipboard.setData(ClipboardData(text: construireRapportClient(data)));
  }

  static Uri? uriItineraireGoogleMaps(String destination) {
    final adresse = destination.trim();
    if (adresse.isEmpty) return null;
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(adresse)}&travelmode=driving',
    );
  }

  static Future<void> lancerItineraire(String destination) async {
    final uri = uriItineraireGoogleMaps(destination);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> demarrerCourseFirestore(String docId) async {
    await FirebaseFirestore.instance.collection('missions').doc(docId).update({
      'statut': 'EN COURSE',
      'courseDemarreeAt': FieldValue.serverTimestamp(),
      'pipeline_updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> ouvrir(
    BuildContext context, {
    required String docId,
    required Map<String, dynamic> data,
    Color couleurAccent = const Color(0xFFD4AF37),
    Color fond = const Color(0xFF000000),
    Future<void> Function()? onDemarrerCourse,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MissionDetailsScreen(
          docId: docId,
          data: data,
          couleurAccent: couleurAccent,
          fond: fond,
          onDemarrerCourse: onDemarrerCourse,
        ),
      ),
    );
  }

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  late Map<String, dynamic> _data;
  bool _missionEnCours = false;
  bool _demarrageEnCours = false;
  bool _missionTerminee = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    final statut = _data['statut']?.toString();
    _missionEnCours = MissionDetailsScreen.estMissionEnCours(statut);
    _missionTerminee = MissionDetailsScreen.estMissionTerminee(statut);
  }

  Future<void> _demarrerCourse() async {
    if (_missionEnCours || _demarrageEnCours) return;
    setState(() => _demarrageEnCours = true);
    try {
      if (widget.onDemarrerCourse != null) {
        await widget.onDemarrerCourse!();
      } else {
        await MissionDetailsScreen.demarrerCourseFirestore(widget.docId);
      }
      if (!mounted) return;
      setState(() {
        _missionEnCours = true;
        _data['statut'] = 'EN COURSE';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text('Impossible de démarrer la course : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _demarrageEnCours = false);
    }
  }

  Future<void> _genererRapport() async {
    await MissionDetailsScreen.copierRapportClient(_data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copié ! Prêt à être envoyé à Françoise/Client'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _piedFeuilleRoute() {
    if (_missionTerminee) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.couleurAccent,
            side: BorderSide(color: widget.couleurAccent.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _genererRapport,
          icon: const Icon(Icons.content_copy_rounded, size: 20),
          label: const Text(
            'Générer rapport',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
          ),
        ),
      );
    }
    if (_missionEnCours) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.couleurAccent.withOpacity(0.45)),
        ),
        child: Text(
          'Mission en cours',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.couleurAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: widget.couleurAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _demarrageEnCours ? null : _demarrerCourse,
        icon: _demarrageEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _demarrageEnCours ? 'Démarrage…' : 'Démarrer la course',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _carteSection({
    required String titre,
    required List<Widget> enfants,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.couleurAccent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titre,
            style: TextStyle(
              color: widget.couleurAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ...enfants,
        ],
      ),
    );
  }

  Widget _ligneDetail(IconData icone, String libelle, String valeur, {VoidCallback? onTap}) {
    final contenu = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: widget.couleurAccent.withOpacity(0.85), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                valeur,
                style: TextStyle(
                  color: onTap != null ? widget.couleurAccent : Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  decoration: onTap != null ? TextDecoration.underline : null,
                  decorationColor: widget.couleurAccent.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return contenu;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: contenu);
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _data['date']?.toString() ?? '—';
    final heureText = _data['heure']?.toString() ?? '—';
    final depart = _data['depart']?.toString() ?? '—';
    final destination = MissionDetailsScreen.destinationMission(_data);
    final statut = _data['statut']?.toString() ?? 'EN ATTENTE';
    final client = _data['client']?.toString() ?? '—';
    final typeMission = _data['type']?.toString() ?? 'ALLER';
    final telephone = MissionDetailsScreen.telephoneClient(_data);
    final consignes = MissionDetailsScreen.consignesSpeciales(_data);
    final itineraire = destination == null
        ? depart
        : (depart.isNotEmpty ? '$depart → $destination' : destination);

    return ColoredBox(
      color: widget.fond,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Retour',
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.couleurAccent, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'FEUILLE DE ROUTE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.couleurAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _carteSection(
                      titre: 'Détails de la mission',
                      enfants: [
                        Text(
                          '$dateText · $heureText',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            _missionEnCours ? 'EN COURSE' : statut,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: widget.couleurAccent.withOpacity(0.2),
                          side: BorderSide(color: widget.couleurAccent.withOpacity(0.5)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(height: 14),
                        _ligneDetail(Icons.alt_route_rounded, 'Itinéraire', itineraire),
                        const SizedBox(height: 10),
                        _ligneDetail(Icons.person_outline, 'Client', client),
                        const SizedBox(height: 10),
                        _ligneDetail(Icons.category_outlined, 'Type', typeMission),
                      ],
                    ),
                    if (destination != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.couleurAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => unawaited(MissionDetailsScreen.lancerItineraire(destination)),
                          icon: const Icon(Icons.directions_car_rounded, size: 20),
                          label: const Text(
                            "Lancer l'itinéraire",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3),
                          ),
                        ),
                      ),
                    ],
                    if (telephone != null || consignes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _carteSection(
                        titre: 'Consignes',
                        enfants: [
                          if (telephone != null) ...[
                            _ligneDetail(
                              Icons.phone_outlined,
                              'Téléphone client',
                              telephone,
                              onTap: () => unawaited(
                                launchUrl(Uri.parse('tel:$telephone'), mode: LaunchMode.externalApplication),
                              ),
                            ),
                            if (consignes.isNotEmpty) const SizedBox(height: 12),
                          ],
                          if (consignes.isNotEmpty)
                            ...consignes.map(
                              (texte) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline, color: widget.couleurAccent.withOpacity(0.75), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        texte,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.82),
                                          fontSize: 12,
                                          height: 1.4,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: _piedFeuilleRoute(),
            ),
          ],
        ),
      ),
    );
  }
}
