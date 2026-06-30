import 'package:flutter/material.dart';

import 'kelegance_missions_service.dart';
import 'kelegance_notification_prefs.dart';
import 'kelegance_notification_service.dart';

/// Écran plein format — préférences notifications (depuis Paramètres).
class KeleganceEcranPreferencesNotifications extends StatelessWidget {
  const KeleganceEcranPreferencesNotifications({
    super.key,
    this.couleurAccent = const Color(0xFFD4AF37),
    this.fond = const Color(0xFF000000),
  });

  final Color couleurAccent;
  final Color fond;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: couleurAccent, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'PRÉFÉRENCES DE NOTIFICATIONS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: couleurAccent,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Alertes push et locales — synchronisées avec votre compte',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: couleurAccent.withOpacity(0.22)),
                ),
                child: KelegancePreferencesNotifications(
                  couleurAccent: couleurAccent,
                  afficherEntete: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switches — alertes proactives (missions, rappels, factures).
class KelegancePreferencesNotifications extends StatefulWidget {
  const KelegancePreferencesNotifications({
    super.key,
    this.couleurAccent = const Color(0xFFD4AF37),
    this.afficherEntete = true,
  });

  final Color couleurAccent;
  final bool afficherEntete;

  @override
  State<KelegancePreferencesNotifications> createState() => _KelegancePreferencesNotificationsState();
}

class _KelegancePreferencesNotificationsState extends State<KelegancePreferencesNotifications> {
  bool _chargement = true;
  bool _nouvelleMission = true;
  bool _rappelDepart1h = true;
  bool _facturePayee = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await KeleganceNotificationPrefs.charger();
    if (!mounted) return;
    setState(() {
      _nouvelleMission = prefs.nouvelleMission;
      _rappelDepart1h = prefs.rappelDepart1h;
      _facturePayee = prefs.facturePayee;
      _chargement = false;
    });
  }

  Future<void> _maj({bool? nouvelleMission, bool? rappelDepart1h, bool? facturePayee}) async {
    if (nouvelleMission != null) _nouvelleMission = nouvelleMission;
    if (rappelDepart1h != null) _rappelDepart1h = rappelDepart1h;
    if (facturePayee != null) _facturePayee = facturePayee;
    setState(() {});

    await KeleganceNotificationPrefs.sauvegarder(
      nouvelleMission: nouvelleMission,
      rappelDepart1h: rappelDepart1h,
      facturePayee: facturePayee,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (widget.afficherEntete) ...[
          Text(
            'Préférences de notifications',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Alertes push et locales — synchronisées avec le serveur',
            style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 10),
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Nouvelle mission', style: TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(
            'Dès qu\'une course vous est assignée (Roissy, Guyancourt…)',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
          ),
          value: _nouvelleMission,
          activeColor: widget.couleurAccent,
          onChanged: (v) => _maj(nouvelleMission: v),
        ),
        const Divider(color: Colors.white12, height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rappel de départ (1 h)', style: TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(
            'Notification 1 h avant chaque transfert planifié',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
          ),
          value: _rappelDepart1h,
          activeColor: widget.couleurAccent,
          onChanged: (v) async {
            await _maj(rappelDepart1h: v);
            if (v) {
              final snap = KeleganceMissionsService.cache;
              if (snap != null) {
                await KeleganceNotificationService.synchroniserRappelsDepart(snap.docs);
              }
            }
          },
        ),
        const Divider(color: Colors.white12, height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Facture payée', style: TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(
            'Quand une facture passe au statut Payée (Bras Droit)',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
          ),
          value: _facturePayee,
          activeColor: widget.couleurAccent,
          onChanged: (v) => _maj(facturePayee: v),
        ),
        ],
      ),
    );
  }
}
