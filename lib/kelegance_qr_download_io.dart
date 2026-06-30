import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> telechargerQrPng(
  Uint8List bytes,
  String nomFichier, {
  required String lienHub,
}) async {
  final fichier = XFile.fromData(
    bytes,
    mimeType: 'image/png',
    name: nomFichier,
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [fichier],
      subject: 'QR Code Hub Kelegance',
      text: lienHub,
    ),
  );
}
