import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'kelegance_qr_download.dart';
import 'kelegance_roles.dart';
import 'kelegance_web_urls.dart';

enum KeleganceQrType { client, brasDroit, collaborateur }

/// Service partagé — génération QR codes Client & Bras Droit (admin).
abstract final class KeleganceQrCodes {
  static const String logoAsset = 'assets/images/kelegance_logo.png';
  static const Color couleurModule = Color(0xFF000000);
  static const int niveauCorrectionErreur = QrErrorCorrectLevel.L;
  static const Color _fond = Color(0xFF0B1426);
  static const Color _fondCarte = Color(0xFF121E33);
  static const Color _or = Color(0xFFD4AF37);
  static const Color _textePrincipal = Color(0xFFF5F0E6);
  static const double tailleApercu = 240;
  static const double tailleLogoCentre = 52;

  static bool utilisateurEstAdmin() => KeleganceRoles.accesOutilsAdmin();

  static String urlPour(KeleganceQrType type) => donneesQr(type);

  /// URL absolue https — payload encodé pour lecture caméra native (Android/iOS).
  static String donneesQr(KeleganceQrType type) {
    final originUri = Uri.parse(KeleganceWebUrls.origine);
    final host = originUri.host;
    if (host.isEmpty) {
      throw StateError('Origine web Kelegance invalide pour le QR code.');
    }

    final (chemin, query) = switch (type) {
      KeleganceQrType.client => (KeleganceWebUrls.cheminHub, null),
      KeleganceQrType.brasDroit => (
          KeleganceWebUrls.cheminHub,
          <String, String>{'profil': KeleganceWebUrls.profilHubBrasDroit},
        ),
      KeleganceQrType.collaborateur => (
          KeleganceWebUrls.cheminChauffeur,
          <String, String>{'role': 'driver'},
        ),
    };

    final uri = Uri(
      scheme: 'https',
      host: host,
      port: _portHttps(originUri),
      path: chemin,
      queryParameters: query,
    );
    final payload = uri.toString();
    _verifierPayloadHub(payload);
    return payload;
  }

  /// Bloque tout payload WhatsApp / téléphone — le QR doit être une URL Hub https.
  static void _verifierPayloadHub(String payload) {
    final lower = payload.toLowerCase();
    if (lower.contains('wa.me') ||
        lower.contains('whatsapp') ||
        lower.startsWith('tel:') ||
        lower.startsWith('whatsapp:')) {
      throw StateError('Payload QR interdit (WhatsApp/tél.) : $payload');
    }
    final uri = Uri.tryParse(payload);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Payload QR invalide — URL https absolue requise : $payload');
    }
  }

  static int? _portHttps(Uri originUri) {
    if (!originUri.hasPort) return null;
    final port = originUri.port;
    if (port == 443) return null;
    return port;
  }

  /// Encode une valeur de query pour l'URL (équivalent ciblé à [Uri.encodeFull] sur les paramètres).
  static String encoderParametreQuery(String valeur) => Uri.encodeQueryComponent(valeur);

  /// Chemin affiché sous le QR (inclut les paramètres de profil).
  static String cheminAffichePour(KeleganceQrType type) {
    final uri = Uri.parse(donneesQr(type));
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }

  static String libellePour(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => 'Client',
        KeleganceQrType.brasDroit => 'Bras Droit',
        KeleganceQrType.collaborateur => 'Collaborateur',
      };

  static String sousTitrePour(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => 'Hub Client',
        KeleganceQrType.brasDroit => 'Admin complet · PWA iOS',
        KeleganceQrType.collaborateur => 'Interface restreinte · PWA iOS',
      };

  static String nomFichierPng(KeleganceQrType type) => switch (type) {
        KeleganceQrType.client => 'kelegance-qr-client.png',
        KeleganceQrType.brasDroit => 'kelegance-qr-bras-droit.png',
        KeleganceQrType.collaborateur => 'kelegance-qr-collaborateur.png',
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

  static Future<ui.Image> _genererQrImage(
    KeleganceQrType type, {
    required double taille,
  }) async {
    final payload = donneesQr(type);
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: niveauCorrectionErreur,
      gapless: false,
      eyeStyle: styleYeux,
      dataModuleStyle: styleModules,
    );
    return painter.toImage(taille);
  }

  static void _dessinerTexteCentre(
    Canvas canvas,
    String text,
    double centreX,
    double y,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(centreX - painter.width / 2, y));
  }

  static Future<Uint8List> genererPng(
    KeleganceQrType type, {
    double largeur = 900,
  }) async {
    final hauteur = largeur * 1.22;
    final centreX = largeur / 2;
    final tailleQr = largeur * 0.56;
    final qrTop = largeur * 0.19;

    final qrImage = await _genererQrImage(type, taille: tailleQr);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, largeur, hauteur));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, largeur, hauteur),
      Paint()..color = _fond,
    );

    final cadre = RRect.fromRectAndRadius(
      Rect.fromLTWH(28, 28, largeur - 56, hauteur - 56),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      cadre,
      Paint()
        ..color = _or.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawRRect(
      cadre.deflate(6),
      Paint()
        ..color = _or.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _dessinerTexteCentre(
      canvas,
      'KELEGANCE PRESTIGE',
      centreX,
      58,
      TextStyle(
        color: _or,
        fontSize: largeur * 0.042,
        fontWeight: FontWeight.w300,
        letterSpacing: 3.6,
      ),
      maxWidth: largeur - 80,
    );

    final qrPad = 18.0;
    final qrBloc = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centreX - tailleQr / 2 - qrPad,
        qrTop - qrPad,
        tailleQr + qrPad * 2,
        tailleQr + qrPad * 2,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(qrBloc, Paint()..color = Colors.white);
    canvas.drawRRect(
      qrBloc,
      Paint()
        ..color = _or.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawImage(
      qrImage,
      Offset(centreX - tailleQr / 2, qrTop),
      Paint(),
    );

    final labelY = qrTop + tailleQr + qrPad + 28;
    _dessinerTexteCentre(
      canvas,
      libellePour(type).toUpperCase(),
      centreX,
      labelY,
      TextStyle(
        color: _or,
        fontSize: largeur * 0.038,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4,
      ),
    );

    _dessinerTexteCentre(
      canvas,
      sousTitrePour(type),
      centreX,
      labelY + largeur * 0.052,
      TextStyle(
        color: _textePrincipal.withOpacity(0.68),
        fontSize: largeur * 0.032,
        letterSpacing: 0.8,
      ),
    );

    final chemin = cheminAffichePour(type);
    final bandeau = RRect.fromRectAndRadius(
      Rect.fromLTWH(72, hauteur - 118, largeur - 144, 52),
      const Radius.circular(8),
    );
    canvas.drawRRect(bandeau, Paint()..color = _fondCarte);
    canvas.drawRRect(
      bandeau,
      Paint()
        ..color = _or.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _dessinerTexteCentre(
      canvas,
      chemin,
      centreX,
      hauteur - 104,
      TextStyle(
        color: _textePrincipal.withOpacity(0.82),
        fontSize: largeur * 0.034,
        letterSpacing: 0.6,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(largeur.toInt(), hauteur.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Impossible de générer le QR code Prestige.');
    }
    return bytes.buffer.asUint8List();
  }

  /// Types à régénérer après correction d'URL (équipe + client).
  static const List<KeleganceQrType> typesPourRegeneration = [
    KeleganceQrType.client,
    KeleganceQrType.collaborateur,
    KeleganceQrType.brasDroit,
  ];

  /// Régénère les PNG en mémoire — utile avant export groupé ou impression.
  static Future<Map<KeleganceQrType, Uint8List>> preparerRegeneration() async {
    final resultats = <KeleganceQrType, Uint8List>{};
    for (final type in typesPourRegeneration) {
      resultats[type] = await genererPng(type);
    }
    return resultats;
  }

  /// Régénère et exporte chaque QR avec l'URL courante ([urlPour]).
  static Future<int> regenererEtExporterTous() async {
    var exportes = 0;
    for (final type in typesPourRegeneration) {
      await telechargerPng(type);
      exportes++;
    }
    return exportes;
  }

  static Future<void> telechargerPng(KeleganceQrType type) async {
    final lien = donneesQr(type);
    final bytes = await genererPng(type);
    await telechargerQrPng(bytes, nomFichierPng(type), lienHub: lien);
  }

  static Future<void> copierLien(BuildContext context, KeleganceQrType type) async {
    await Clipboard.setData(ClipboardData(text: donneesQr(type)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Lien copié dans le presse-papiers.'),
      ),
    );
  }
}
