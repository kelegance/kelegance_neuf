import 'dart:async';

import 'package:flutter/material.dart';

import 'kelegance_qr_cadre_prestige.dart';
import 'kelegance_qr_codes.dart';
import 'kelegance_qr_scanner_page.dart';
import 'kelegance_invitation_chauffeur_ui.dart';
import 'kelegance_roles.dart';

/// Page admin — QR Collaborateur (vert) et Bras Droit (or).
class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  KeleganceQrType _typeSelectionne = KeleganceQrType.collaborateur;
  bool _telechargementEnCours = false;
  bool _regenerationEnCours = false;

  static const Color _vertCollaborateur = Color(0xFF2E7D52);
  static const Color _orBrasDroit = KeleganceQrTheme.or;

  @override
  void initState() {
    super.initState();
    unawaited(
      KeleganceRoles.initialiserPourUtilisateurCourant().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  Future<void> _telecharger() async {
    setState(() => _telechargementEnCours = true);
    try {
      await KeleganceQrCodes.telechargerPng(_typeSelectionne);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('QR code Prestige exporté — enregistrez ou partagez le PNG.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _telechargementEnCours = false);
    }
  }

  Future<void> _regenererTous() async {
    setState(() => _regenerationEnCours = true);
    try {
      final exportes = await KeleganceQrCodes.regenererEtExporterTous();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('$exportes QR code(s) régénéré(s) avec les URLs actuelles.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur régénération : $e')),
      );
    } finally {
      if (mounted) setState(() => _regenerationEnCours = false);
    }
  }

  Future<void> _ouvrirScanner() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const KeleganceQrScannerPage()),
    );
    if (!mounted || code == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('QR détecté : $code'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!KeleganceRoles.peutAccederRoutesAdmin()) {
      return Scaffold(
        backgroundColor: KeleganceQrTheme.fond,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: KeleganceQrTheme.or),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Accès réservé aux Bras Droit Kelegance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: KeleganceQrTheme.texteDiscret, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final payloadHub = KeleganceQrCodes.donneesQr(_typeSelectionne);

    return Scaffold(
      backgroundColor: KeleganceQrTheme.fond,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _orBrasDroit),
        title: const Text(
          'QR CODES ÉQUIPE',
          style: TextStyle(
            color: KeleganceQrTheme.or,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Inviter un chauffeur',
            icon: const Icon(Icons.group_add_outlined, color: _orBrasDroit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KelegancePageInvitationEquipe()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Android : téléchargement APK au scan.\n'
                'iPhone : installation PWA puis console selon le profil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KeleganceQrTheme.textePrincipal.withOpacity(0.55),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _boutonType(
                    type: KeleganceQrType.collaborateur,
                    titre: 'COLLABORATEUR',
                    sousTitre: 'Interface restreinte',
                    couleurFond: _vertCollaborateur,
                    couleurTexte: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  _boutonType(
                    type: KeleganceQrType.brasDroit,
                    titre: 'BRAS DROIT',
                    sousTitre: 'Admin complet',
                    couleurFond: _orBrasDroit,
                    couleurTexte: Colors.black,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: KeleganceQrCadrePrestige(
                  type: _typeSelectionne,
                ),
              ),
              const SizedBox(height: 18),
              SelectableText(
                payloadHub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KeleganceQrTheme.textePrincipal.withOpacity(0.72),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _ouvrirScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scanner un QR (caméra ou galerie)', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orBrasDroit,
                  side: BorderSide(color: _orBrasDroit.withOpacity(0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _regenerationEnCours ? null : _regenererTous,
                icon: _regenerationEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: KeleganceQrTheme.or),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  _regenerationEnCours ? 'Régénération…' : 'Régénérer tous les QR (URLs actuelles)',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KeleganceQrTheme.textePrincipal.withOpacity(0.85),
                  side: BorderSide(color: _orBrasDroit.withOpacity(0.28)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => KeleganceQrCodes.copierLien(context, _typeSelectionne),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copier le lien', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _orBrasDroit,
                        side: BorderSide(color: _orBrasDroit.withOpacity(0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _telechargementEnCours ? null : _telecharger,
                      icon: _telechargementEnCours
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _telechargementEnCours ? 'Export…' : 'Télécharger PNG',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _typeSelectionne == KeleganceQrType.collaborateur
                            ? _vertCollaborateur
                            : _orBrasDroit,
                        foregroundColor:
                            _typeSelectionne == KeleganceQrType.collaborateur ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boutonType({
    required KeleganceQrType type,
    required String titre,
    required String sousTitre,
    required Color couleurFond,
    required Color couleurTexte,
  }) {
    final selectionne = _typeSelectionne == type;

    return Expanded(
      child: Material(
        color: selectionne ? couleurFond : couleurFond.withOpacity(0.28),
        borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
        child: InkWell(
          onTap: () => setState(() => _typeSelectionne = type),
          borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KeleganceQrTheme.rayonBouton),
              border: Border.all(
                color: selectionne ? couleurFond : couleurFond.withOpacity(0.45),
                width: selectionne ? 1.6 : 0.8,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  type == KeleganceQrType.collaborateur ? Icons.person_outline : Icons.badge_outlined,
                  color: couleurTexte,
                  size: 22,
                ),
                const SizedBox(height: 8),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: couleurTexte,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sousTitre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: couleurTexte.withOpacity(0.8),
                    fontSize: 9,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
