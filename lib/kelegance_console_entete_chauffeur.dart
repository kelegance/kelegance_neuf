import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kelegance_profil_chauffeur_stream.dart';

/// Bandeau accueil chauffeur — nom, statut en ligne, accès notifications.
class KeleganceConsoleEnteteChauffeur extends StatelessWidget {
  const KeleganceConsoleEnteteChauffeur({
    super.key,
    required this.enLigne,
    required this.onBasculerEnLigne,
    required this.onOuvrirNotifications,
    this.reserveAppBar = false,
  });

  final bool enLigne;
  final VoidCallback onBasculerEnLigne;
  final VoidCallback onOuvrirNotifications;
  final bool reserveAppBar;

  static const Color _or = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (kDebugMode) debugPrint('KeleganceConsoleEntete — aucun utilisateur connecté');
      return _coque(
        context,
        child: const Text(
          'Chargement…',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    final topInset = reserveAppBar ? kToolbarHeight : 0.0;

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: StreamBuilder<KeleganceProfilChauffeurSnapshot>(
        stream: KeleganceProfilChauffeurStream.ecouter(),
        builder: (context, profilSnap) {
          final profil = profilSnap.data;
          final userName = profil?.nom;
          final chargementProfil = profil == null || profil.chargement;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('presence').doc(uid).snapshots(),
            builder: (context, presenceSnap) {
              if (presenceSnap.hasError && kDebugMode) {
                debugPrint('KeleganceConsoleEntete — présence uid=$uid: ${presenceSnap.error}');
              }

              final presence = presenceSnap.data?.data();
              final enLigneFirestore = presence?['enLigne'] == true;
              final statutAffiche = enLigne || enLigneFirestore;

              final nomAffiche = chargementProfil
                  ? 'Chargement…'
                  : (userName ?? user!.email?.split('@').first ?? 'Chauffeur');

              final notifActives = profil?.notificationPrefs?['nouvelleMission'] != false;

              return _coque(
                context,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomAffiche,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statutAffiche ? 'Connecté · visible équipe' : 'Hors ligne',
                            style: TextStyle(
                              color: statutAffiche ? Colors.greenAccent.withOpacity(0.85) : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          if (profil?.erreur != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Profil : ${profil!.erreur}',
                                style: TextStyle(color: Colors.redAccent.withOpacity(0.85), fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (presenceSnap.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Présence : ${presenceSnap.error}',
                                style: TextStyle(color: Colors.redAccent.withOpacity(0.85), fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Préférences notifications',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: onOuvrirNotifications,
                          icon: Icon(
                            notifActives ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                            color: _or.withOpacity(0.95),
                            size: 22,
                          ),
                        ),
                        if (notifActives)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0D0D0D), width: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: statutAffiche ? Colors.green : Colors.redAccent.shade700,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onBasculerEnLigne,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statutAffiche ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statutAffiche ? 'EN LIGNE' : 'HORS LIGNE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _coque(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D).withOpacity(0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _or.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
