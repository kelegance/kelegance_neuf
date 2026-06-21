import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'kelegance_web_urls.dart';

Future<void> telechargerQrPng(Uint8List bytes, String nomFichier) async {
  final fichier = XFile.fromData(
    bytes,
    mimeType: 'image/png',
    name: nomFichier,
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [fichier],
      subject: 'QR Code réservation Kelegance',
      text: 'Lien client : ${KeleganceWebUrls.reserver}',
    ),
  );
}
