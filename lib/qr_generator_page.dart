import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'kelegance_qr_codes.dart';

abstract final class _QrTheme {
  static const Color fond = Color(0xFF0B1426);
  static const Color fondCarte = Color(0xFF121E33);
  static const Color or = Color(0xFFD4AF37);
  static const Color textePrincipal = Color(0xFFF5F0E6);
  static const Color texteDiscret = Color(0x99F5F0E6);
  static const double rayonBouton = 10.0;
}

/// Page admin — génération des QR codes Client et Bras Droit.
class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  KeleganceQrType _typeSelectionne = KeleganceQrType.client;
  ImageProvider? _logo;
  bool _telechargementEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerLogo();
  }

  Future<void> _chargerLogo() async {
    final logo = await KeleganceQrCodes.chargerLogo();
    if (!mounted) return;
    setState(() => _logo = logo);
  }

  Future<void> _telecharger() async {
    setState(() => _telechargementEnCours = true);
    try {
      await KeleganceQrCodes.telechargerPng(_typeSelectionne);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('QR code exporté — enregistrez ou partagez le PNG.'),
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

  @override
  Widget build(BuildContext context) {
    if (!KeleganceQrCodes.utilisateurEstAdmin()) {
      return Scaffold(
        backgroundColor: _QrTheme.fond,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: _QrTheme.or),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Accès réservé à l\'administrateur Kelegance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _QrTheme.texteDiscret, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final url = KeleganceQrCodes.urlPour(_typeSelectionne);
    const or = _QrTheme.or;

    return Scaffold(
      backgroundColor: _QrTheme.fond,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: or),
        title: const Text(
          'QR CODES PRESTIGE',
          style: TextStyle(
            color: _QrTheme.or,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Générez les codes d\'accès directs pour vos clients et vos Bras Droits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _QrTheme.textePrincipal.withOpacity(0.55),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _boutonType(
                      type: KeleganceQrType.client,
                      titre: 'CLIENT',
                      sousTitre: '/reserver',
                      couleurFond: or,
                      couleurTexte: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _boutonType(
                      type: KeleganceQrType.brasDroit,
                      titre: 'BRAS DROIT',
                      sousTitre: '/gestion',
                      couleurFond: _QrTheme.fondCarte,
                      couleurTexte: or,
                      bordureOr: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_QrTheme.rayonBouton + 4),
                    border: Border.all(color: or.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: or.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: url,
                    size: KeleganceQrCodes.tailleApercu,
                    backgroundColor: Colors.white,
                    eyeStyle: KeleganceQrCodes.styleYeux,
                    dataModuleStyle: KeleganceQrCodes.styleModules,
                    embeddedImage: _logo,
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(
                        KeleganceQrCodes.tailleLogoCentre,
                        KeleganceQrCodes.tailleLogoCentre,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                KeleganceQrCodes.libellePour(_typeSelectionne).toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _QrTheme.or,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _QrTheme.textePrincipal.withOpacity(0.72),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => KeleganceQrCodes.copierLien(context, _typeSelectionne),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copier le lien', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: or,
                        side: BorderSide(color: or.withOpacity(0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_QrTheme.rayonBouton),
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
                        backgroundColor: or,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_QrTheme.rayonBouton),
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
    bool bordureOr = false,
  }) {
    final selectionne = _typeSelectionne == type;
    const or = _QrTheme.or;

    return Material(
      color: selectionne ? couleurFond : couleurFond.withOpacity(0.35),
      borderRadius: BorderRadius.circular(_QrTheme.rayonBouton),
      child: InkWell(
        onTap: () => setState(() => _typeSelectionne = type),
        borderRadius: BorderRadius.circular(_QrTheme.rayonBouton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_QrTheme.rayonBouton),
            border: Border.all(
              color: bordureOr
                  ? (selectionne ? or : or.withOpacity(0.35))
                  : (selectionne ? Colors.transparent : or.withOpacity(0.2)),
              width: selectionne ? 1.4 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type == KeleganceQrType.client ? Icons.person_outline : Icons.badge_outlined,
                color: couleurTexte,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                titre,
                style: TextStyle(
                  color: couleurTexte,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sousTitre,
                style: TextStyle(
                  color: couleurTexte.withOpacity(0.75),
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
