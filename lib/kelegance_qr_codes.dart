import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'kelegance_documents_pdf_service.dart';
import 'kelegance_init_firestore.dart';
import 'kelegance_qr_download.dart';
import 'kelegance_web_urls.dart';

enum KeleganceQrType { client, brasDroit }

/// Service partagé — génération QR codes Client & Bras Droit (admin).
abstract final class KeleganceQrCodes {
  static const String logoAsset = 'assets/images/kelegance_logo.png';
  static const Color couleurModule = Color(0xFF0B1426);
  static const double tailleApercu = 240;
  static const double tailleLogoCentre = 52;

  static bool utilisateurEstAdmin() {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
    if (email == null || email.isEmpty) return false;
    return email == KeleganceIdentiteDocuments.emailAdmin.toLowerCase() ||
        email == KeleganceProfilsBootstrap.emailAdminNicolas.toLowerCase();
  }

  static String urlPour(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => KeleganceWebUrls.reserver,
        KeleganceQrType.brasDroit => KeleganceWebUrls.gestion,
      };

  static String libellePour(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => 'Client',
        KeleganceQrType.brasDroit => 'Bras Droit',
      };

  static String nomFichierPng(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => 'kelegance-qr-client.png',
        KeleganceQrType.brasDroit => 'kelegance-qr-bras-droit.png',
      };

  static const QrEyeStyle styleYeux = QrEyeStyle(
    eyeShape: QrEyeShape.square,
    color: couleurModule,
  );

  static const QrDataModuleStyle styleModules = QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.square,
    color: couleurModule,
  );

  static Future<ImageProvider> chargerLogo() async {
    final data = await rootBundle.load(logoAsset);
    return MemoryImage(data.buffer.asUint8List());
  }

  static Future<ui.Image> _chargerLogoUiImage() async {
    final data = await rootBundle.load(logoAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<Uint8List> genererPng(
    KeleganceQrType type, {
    double taille = 1024,
  }) async {
    final logo = await _chargerLogoUiImage();
    final tailleLogo = taille * 0.18;
    final painter = QrPainter(
      data: urlPour(type),
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: styleYeux,
      dataModuleStyle: styleModules,
      embeddedImage: logo,
      embeddedImageStyle: QrEmbeddedImageStyle(
        size: Size(tailleLogo, tailleLogo),
      ),
    );
    final image = await painter.toImageData(
      taille,
      format: ui.ImageByteFormat.png,
    );
    if (image == null) {
      throw StateError('Impossible de générer le QR code.');
    }
    return image.buffer.asUint8List();
  }

  static Future<void> telechargerPng(KeleganceQrType type) async {
    final bytes = await genererPng(type);
    await telechargerQrPng(bytes, nomFichierPng(type));
  }

  static Future<void> copierLien(BuildContext context, KeleganceQrType type) async {
    await Clipboard.setData(ClipboardData(text: urlPour(type)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Lien copié dans le presse-papiers.'),
      ),
    );
  }
}
