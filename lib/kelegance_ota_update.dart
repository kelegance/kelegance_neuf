import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'kelegance_platform.dart';
import 'kelegance_reload.dart';
import 'kelegance_web_urls.dart';

/// Métadonnées de release Android publiées sur Netlify (/releases/android-latest.json).
class KeleganceOtaManifest {
  const KeleganceOtaManifest({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.releaseNotes = '',
    this.mandatory = false,
  });

  final String version;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool mandatory;

  factory KeleganceOtaManifest.fromJson(Map<String, dynamic> json) {
    final build = json['buildNumber'] ?? json['versionCode'] ?? json['build'];
    return KeleganceOtaManifest(
      version: json['version']?.toString() ?? '',
      buildNumber: build is num ? build.toInt() : int.tryParse(build?.toString() ?? '') ?? 0,
      apkUrl: json['apkUrl']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      mandatory: json['mandatory'] == true,
    );
  }

  bool get valide => version.isNotEmpty && buildNumber > 0 && apkUrl.startsWith('https://');
}

/// Mises à jour OTA Android — téléchargement Dart + installation native (sans OkHttp).
abstract final class KeleganceOtaUpdate {
  static const MethodChannel _canal = MethodChannel('com.example.kelegance_neuf/ota');
  static const Duration _delaiEntreVerifications = Duration(hours: 4);

  static DateTime? _derniereVerification;
  static bool _dialogueOuvert = false;
  static bool _installationEnCours = false;
  static bool _annulerDemande = false;
  static http.Client? _clientHttp;

  static bool get disponible => !kIsWeb && keleganceEstAndroid;

  static Future<KeleganceOtaManifest?> recupererManifeste() async {
    if (!disponible) return null;
    try {
      final response = await http
          .get(
            Uri.parse(KeleganceWebUrls.androidReleaseManifest).replace(
              queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final manifeste = KeleganceOtaManifest.fromJson(json);
      return manifeste.valide ? manifeste : null;
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance OTA manifeste: $e');
      return null;
    }
  }

  static Future<({PackageInfo info, KeleganceOtaManifest? manifeste, bool miseAJour})?> analyser() async {
    if (!disponible) return null;
    final info = await PackageInfo.fromPlatform();
    final manifeste = await recupererManifeste();
    if (manifeste == null) return (info: info, manifeste: null, miseAJour: false);
    final buildActuel = int.tryParse(info.buildNumber) ?? 0;
    return (
      info: info,
      manifeste: manifeste,
      miseAJour: manifeste.buildNumber > buildActuel,
    );
  }

  static Future<void> verifierAuDemarrage(BuildContext context) async {
    if (!disponible || _dialogueOuvert) return;
    final maintenant = DateTime.now();
    if (_derniereVerification != null &&
        maintenant.difference(_derniereVerification!) < _delaiEntreVerifications) {
      return;
    }
    _derniereVerification = maintenant;

    final resultat = await analyser();
    if (!context.mounted || resultat == null || !resultat.miseAJour || resultat.manifeste == null) {
      return;
    }
    await _afficherDialogue(
      context,
      info: resultat.info,
      manifeste: resultat.manifeste!,
      demarrageAutomatique: true,
    );
  }

  static Future<void> verifierManuellement(BuildContext context) async {
    if (!disponible) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mises à jour OTA disponibles uniquement sur l\'APK Android natif.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF121E33),
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Recherche de mise à jour…', style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );

    final resultat = await analyser();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (resultat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de contacter le serveur de mise à jour.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!resultat.miseAJour || resultat.manifeste == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application à jour — v${resultat.info.version}'),
          backgroundColor: const Color(0xFFD4AF37),
        ),
      );
      return;
    }

    await _afficherDialogue(
      context,
      info: resultat.info,
      manifeste: resultat.manifeste!,
      demarrageAutomatique: false,
    );
  }

  static Future<void> _afficherDialogue(
    BuildContext context, {
    required PackageInfo info,
    required KeleganceOtaManifest manifeste,
    required bool demarrageAutomatique,
  }) async {
    if (_dialogueOuvert || !context.mounted) return;
    _dialogueOuvert = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !manifeste.mandatory,
      builder: (ctx) => _DialogueOta(
        versionActuelle: info.version,
        manifeste: manifeste,
        demarrageAutomatique: demarrageAutomatique,
      ),
    );

    _dialogueOuvert = false;
  }

  static Future<void> lancerInstallation({
    required KeleganceOtaManifest manifeste,
    required ValueChanged<double?> onProgression,
    required ValueChanged<String> onStatut,
    required VoidCallback onTermine,
    required ValueChanged<String> onErreur,
  }) async {
    if (_installationEnCours) {
      onErreur('Une mise à jour est déjà en cours.');
      return;
    }

    _installationEnCours = true;
    _annulerDemande = false;
    onStatut('Téléchargement de la mise à jour…');

    try {
      final cache = await getTemporaryDirectory();
      final dossier = Directory('${cache.path}/ota');
      if (!await dossier.exists()) {
        await dossier.create(recursive: true);
      }
      final fichier = File('${dossier.path}/kelegance-${manifeste.version}.apk');
      if (await fichier.exists()) {
        await fichier.delete();
      }

      final client = http.Client();
      _clientHttp = client;
      final requete = http.Request('GET', Uri.parse(manifeste.apkUrl));
      final reponse = await client.send(requete).timeout(const Duration(minutes: 20));

      if (reponse.statusCode != 200) {
        onErreur('Téléchargement impossible (HTTP ${reponse.statusCode}).');
        return;
      }

      final total = reponse.contentLength ?? 0;
      var recu = 0;
      final ecriture = fichier.openWrite();
      await for (final morceau in reponse.stream) {
        if (_annulerDemande) {
          await ecriture.close();
          if (await fichier.exists()) await fichier.delete();
          onErreur('Téléchargement annulé.');
          return;
        }
        ecriture.add(morceau);
        recu += morceau.length;
        if (total > 0) {
          onProgression(recu / total);
        } else {
          onProgression(null);
        }
        onStatut('Téléchargement en cours…');
      }
      await ecriture.close();

      if (_annulerDemande) {
        if (await fichier.exists()) await fichier.delete();
        onErreur('Téléchargement annulé.');
        return;
      }

      if (!await fichier.exists() || await fichier.length() < 1024) {
        onErreur('Fichier APK invalide ou incomplet.');
        return;
      }

      onProgression(1);
      onStatut('Installation — validez sur l\'écran système Android.');

      final installe = await _canal.invokeMethod<bool>('installApk', {'path': fichier.path});
      if (installe != true) {
        onErreur('Autorisez l\'installation d\'applications inconnues pour Kelegance.');
        return;
      }
      onTermine();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION') {
        onErreur('Autorisez l\'installation d\'applications inconnues pour Kelegance.');
      } else {
        onErreur(e.message ?? 'Échec de l\'installation.');
      }
    } on TimeoutException {
      onErreur('Délai dépassé — vérifiez votre connexion et réessayez.');
    } catch (e) {
      onErreur('Erreur réseau : $e');
    } finally {
      _clientHttp?.close();
      _clientHttp = null;
      _installationEnCours = false;
      _annulerDemande = false;
    }
  }

  static Future<void> annulerInstallation() async {
    _annulerDemande = true;
    _clientHttp?.close();
    _clientHttp = null;
  }

  /// Android natif (OTA APK) ou rafraîchissement PWA / web.
  static Future<void> verifierMiseAJourUniverselle(BuildContext context) async {
    if (disponible) {
      await verifierManuellement(context);
      return;
    }
    await verifierMiseAJourWeb(context);
  }

  static Future<void> verifierMiseAJourWeb(BuildContext context) async {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF121E33),
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Vérification des ressources…', style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );

    String versionLocale = '—';
    int buildLocal = 0;
    try {
      final info = await PackageInfo.fromPlatform();
      versionLocale = info.version;
      buildLocal = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}

    int? buildServeur;
    String? versionServeur;
    try {
      final response = await http
          .get(Uri.parse(KeleganceWebUrls.webReleaseManifest))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          versionServeur = json['version']?.toString();
          final build = json['buildNumber'] ?? json['build'];
          buildServeur = build is num ? build.toInt() : int.tryParse(build?.toString() ?? '');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance web manifeste: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final nouvelleVersion = buildServeur != null && buildServeur > buildLocal;

    if (!nouvelleVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            buildServeur == null
                ? 'Ressources vérifiées — v$versionLocale (connexion serveur limitée).'
                : 'Application à jour — v$versionLocale',
          ),
          backgroundColor: const Color(0xFFD4AF37),
        ),
      );
      return;
    }

    final recharger = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121E33),
        title: const Text('Mise à jour disponible', style: TextStyle(color: Color(0xFFD4AF37))),
        content: Text(
          'Version $versionServeur disponible (vous : v$versionLocale).\n'
          'Rechargez pour appliquer la dernière version.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recharger maintenant'),
          ),
        ],
      ),
    );

    if (recharger == true && context.mounted) {
      await KeleganceReloadWeb.recharger();
    }
  }
}

class _DialogueOta extends StatefulWidget {
  const _DialogueOta({
    required this.versionActuelle,
    required this.manifeste,
    required this.demarrageAutomatique,
  });

  final String versionActuelle;
  final KeleganceOtaManifest manifeste;
  final bool demarrageAutomatique;

  @override
  State<_DialogueOta> createState() => _DialogueOtaState();
}

class _DialogueOtaState extends State<_DialogueOta> {
  bool _installationEnCours = false;
  double? _progression;
  String _statut = '';
  String? _erreur;

  @override
  void dispose() {
    if (_installationEnCours) {
      unawaited(KeleganceOtaUpdate.annulerInstallation());
    }
    super.dispose();
  }

  Future<void> _installer() async {
    setState(() {
      _installationEnCours = true;
      _erreur = null;
      _progression = null;
      _statut = 'Préparation…';
    });

    await KeleganceOtaUpdate.lancerInstallation(
      manifeste: widget.manifeste,
      onProgression: (p) {
        if (!mounted) return;
        setState(() => _progression = p);
      },
      onStatut: (s) {
        if (!mounted) return;
        setState(() => _statut = s);
      },
      onTermine: () {
        if (!mounted) return;
        setState(() => _installationEnCours = false);
      },
      onErreur: (e) {
        if (!mounted) return;
        setState(() {
          _installationEnCours = false;
          _erreur = e;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.manifeste.releaseNotes.trim();
    return AlertDialog(
      backgroundColor: const Color(0xFF121E33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x66D4AF37)),
      ),
      title: const Text(
        'Mise à jour disponible',
        style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w500, letterSpacing: 0.6),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'v${widget.versionActuelle} → v${widget.manifeste.version}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            if (notes.isNotEmpty)
              Text(notes, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12, height: 1.4)),
            if (_installationEnCours) ...[
              const SizedBox(height: 16),
              if (_progression != null) ...[
                LinearProgressIndicator(
                  value: _progression,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFD4AF37),
                  minHeight: 4,
                ),
                const SizedBox(height: 8),
              ] else
                const LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  color: Color(0xFFD4AF37),
                  minHeight: 4,
                ),
              const SizedBox(height: 8),
              Text(_statut, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Text(_erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
            if (widget.demarrageAutomatique && !widget.manifeste.mandatory && !_installationEnCours) ...[
              const SizedBox(height: 10),
              Text(
                'Vous pouvez reporter — rappel dans quelques heures.',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.manifeste.mandatory && !_installationEnCours)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard', style: TextStyle(color: Colors.white54)),
          ),
        if (!_installationEnCours)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: _installer,
            child: const Text('Installer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
