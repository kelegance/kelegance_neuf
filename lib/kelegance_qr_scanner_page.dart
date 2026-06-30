import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'kelegance_qr_cadre_prestige.dart';

/// Lecteur QR — caméra live + import galerie (évite les erreurs de lecture en conditions difficiles).
class KeleganceQrScannerPage extends StatefulWidget {
  const KeleganceQrScannerPage({super.key});

  @override
  State<KeleganceQrScannerPage> createState() => _KeleganceQrScannerPageState();
}

class _KeleganceQrScannerPageState extends State<KeleganceQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _analyseGalerie = false;
  String? _dernierCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _traiterCode(String? raw) {
    final code = raw?.trim();
    if (code == null || code.isEmpty || code == _dernierCode) return;
    _dernierCode = code;
    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  Future<void> _chargerDepuisGalerie() async {
    if (_analyseGalerie || kIsWeb) return;
    setState(() => _analyseGalerie = true);
    try {
      final fichier = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (fichier == null || !mounted) return;

      final capture = await _controller.analyzeImage(fichier.path);
      if (!mounted) return;

      final codes = capture?.barcodes ?? const <Barcode>[];
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Aucun QR code détecté dans cette image.'),
          ),
        );
        return;
      }

      final valeur = codes.first.rawValue;
      if (valeur == null || valeur.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('QR code illisible — essayez une autre photo.'),
          ),
        );
        return;
      }
      _traiterCode(valeur);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur galerie : $e')),
      );
    } finally {
      if (mounted) setState(() => _analyseGalerie = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: KeleganceQrTheme.or),
        title: const Text(
          'SCANNER QR',
          style: TextStyle(
            color: KeleganceQrTheme.or,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Charger depuis la galerie',
              onPressed: _analyseGalerie ? null : _chargerDepuisGalerie,
              icon: _analyseGalerie
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: KeleganceQrTheme.or),
                    )
                  : const Icon(Icons.photo_library_outlined, color: KeleganceQrTheme.or),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final codes = capture.barcodes;
                    if (codes.isEmpty) return;
                    _traiterCode(codes.first.rawValue);
                  },
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: KeleganceQrTheme.or.withOpacity(0.65), width: 1.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              child: Column(
                children: [
                  Text(
                    kIsWeb
                        ? 'Cadrez le QR code avec la webcam.'
                        : 'Cadrez le QR code ou importez une photo depuis la galerie.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.4),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _analyseGalerie ? null : _chargerDepuisGalerie,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Charger une image', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KeleganceQrTheme.or,
                        side: BorderSide(color: KeleganceQrTheme.or.withOpacity(0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
