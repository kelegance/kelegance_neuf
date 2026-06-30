import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'kelegance_dispatch_sollicitation.dart';
import 'kelegance_presence_service.dart';
import 'kelegance_roles.dart';

/// Tableau de bord — collaborateurs en temps réel (Bras Droit uniquement).
class KelegancePresenceEquipe extends StatelessWidget {
  const KelegancePresenceEquipe({super.key, this.compact = false});

  /// Version réduite pour le Drawer.
  final bool compact;

  static const Color _or = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KeleganceRoles.notifierBrasDroit,
      builder: (context, _, __) {
        if (!KeleganceRoles.accesOutilsAdmin()) {
          return const SizedBox.shrink();
        }
        return _buildContenu(context);
      },
    );
  }

  Widget _buildContenu(BuildContext context) {
    final monUid = FirebaseAuth.instance.currentUser?.uid;

    final contenu = KelegancePresenceStreamBuilder(
      filtre: (docs) => KelegancePresenceService.collaborateursVisibles(
        docs,
        monUid: monUid,
        actifsSeulement: false,
      ),
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _or),
              ),
            ),
          );
        }

        final docs = snapshot.docs;
        final actifs = docs.where((doc) {
          final statut = KelegancePresenceService.presenterStatut(
            doc.data() as Map<String, dynamic>,
          );
          return statut.libelle != 'Hors ligne';
        }).length;

        if (docs.isEmpty) {
          return Text(
            'Aucun collaborateur référencé.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: compact ? 10 : 11,
              fontStyle: FontStyle.italic,
            ),
          );
        }

        final lignes = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _LigneCollaborateur(
            docId: doc.id,
            data: data,
            compact: compact,
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (live && !compact)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Présence synchronisée',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.cyanAccent.withOpacity(0.75), fontSize: 9),
                ),
              ),
            if (!compact)
              Text(
                '$actifs en ligne · ${docs.length} collaborateur(s)',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            if (!compact) const SizedBox(height: 8),
            ...lignes,
          ],
        );
      },
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ÉQUIPE PRÉSENTE',
              style: TextStyle(
                color: _or.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            contenu,
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _or.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, color: _or.withOpacity(0.9), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ÉQUIPE EN TEMPS RÉEL',
                  style: TextStyle(
                    color: _or,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          contenu,
        ],
      ),
    );
  }
}

class _LigneCollaborateur extends StatelessWidget {
  const _LigneCollaborateur({
    required this.docId,
    required this.data,
    this.compact = false,
  });

  final String docId;
  final Map<String, dynamic> data;
  final bool compact;

  static const Color _or = Color(0xFFD4AF37);
  static const Color _orangeSollicitation = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final nom = data['name']?.toString().trim().isNotEmpty == true
        ? data['name'].toString()
        : (data['email']?.toString() ?? 'Chauffeur');
    final presentation = KelegancePresenceService.presenterStatut(data);
    final sollicitation = KeleganceDispatchSollicitation.estActive(data);
    final enLigne = data['enLigne'] == true;
    final enCourse = data['enCourse'] == true;
    final peutSolliciter = enLigne && !enCourse;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 8),
      child: Row(
        children: [
          Container(
            width: compact ? 7 : 9,
            height: compact ? 7 : 9,
            decoration: BoxDecoration(
              color: presentation.couleur,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: presentation.couleur.withOpacity(0.45),
                  blurRadius: compact ? 3 : 5,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              nom,
              style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            presentation.libelle,
            style: TextStyle(
              color: presentation.couleur.withOpacity(0.95),
              fontSize: compact ? 9 : 10,
              letterSpacing: 0.3,
            ),
          ),
          if (peutSolliciter && !compact) ...[
            const SizedBox(width: 8),
            Material(
              color: sollicitation ? _orangeSollicitation.withOpacity(0.22) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: sollicitation
                    ? null
                    : () async {
                        await KeleganceDispatchSollicitation.envoyer(
                          chauffeurUid: docId,
                          chauffeurEmail: data['email']?.toString(),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: _orangeSollicitation,
                            content: Text('Sollicitation envoyée à $nom'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    sollicitation ? Icons.hourglass_top_rounded : Icons.notifications_active_outlined,
                    size: 18,
                    color: sollicitation ? _orangeSollicitation : _or,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
