import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'kelegance_bon_commande_service.dart';
import 'kelegance_factures_service.dart';
import 'kelegance_missions_service.dart';
import 'kelegance_notification_service.dart';
import 'kelegance_presence_service.dart';

/// Démarre / arrête les services live selon la session Firebase Auth.
Future<void> keleganceSynchroniserServicesLiveAvecAuth(User? user) async {
  if (user == null) {
    await KeleganceMissionsService.arreter();
    await KeleganceFacturesService.arreter();
    await KelegancePresenceService.arreter();
    await KeleganceBonCommandeService.arreter();
    await KeleganceNotificationService.arreter();
    return;
  }
  KeleganceMissionsService.demarrer();
  await KeleganceFacturesService.demarrerPourUtilisateur(user);
  await KelegancePresenceService.demarrerEcoutePourUtilisateur(user);
  await KeleganceBonCommandeService.demarrerPourUtilisateur(user);
  await KeleganceNotificationService.demarrerPourUtilisateur(user);
}

/// Bandeau discret « synchronisé » — réagit aux mises à jour missions et factures.
class KeleganceLivePulseHeader extends StatefulWidget {
  const KeleganceLivePulseHeader({super.key, required this.child});

  final Widget child;

  @override
  State<KeleganceLivePulseHeader> createState() => _KeleganceLivePulseHeaderState();
}

class _KeleganceLivePulseHeaderState extends State<KeleganceLivePulseHeader> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    KeleganceMissionsService.derniereMiseAJour.addListener(_pulse);
    KeleganceFacturesService.derniereMiseAJour.addListener(_pulse);
    KelegancePresenceService.derniereMiseAJour.addListener(_pulse);
    KeleganceBonCommandeService.derniereMiseAJour.addListener(_pulse);
  }

  @override
  void dispose() {
    KeleganceMissionsService.derniereMiseAJour.removeListener(_pulse);
    KeleganceFacturesService.derniereMiseAJour.removeListener(_pulse);
    KelegancePresenceService.derniereMiseAJour.removeListener(_pulse);
    KeleganceBonCommandeService.derniereMiseAJour.removeListener(_pulse);
    _timer?.cancel();
    super.dispose();
  }

  void _pulse() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _visible = true);
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.amber.withOpacity(_visible ? 0.9 : 0),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Mise à jour…',
                style: TextStyle(
                  color: Colors.amber.withOpacity(_visible ? 0.85 : 0),
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }
}
