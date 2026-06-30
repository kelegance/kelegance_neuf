import 'package:flutter/foundation.dart';

/// URLs publiques Kelegance (Netlify / Firebase Hosting).
abstract final class KeleganceWebUrls {
  /// Domaine de production — surcharge possible via `--dart-define=KELEGANCE_WEB_ORIGIN=https://votre-domaine.netlify.app`.
  static const String domaineProduction = String.fromEnvironment(
    'KELEGANCE_WEB_ORIGIN',
    defaultValue: 'https://kelegance.web.app',
  );

  static const String cheminReserver = '/reserver';
  static const String cheminHub = '/hub';
  static const String cheminGestion = '/gestion';
  static const String cheminChauffeur = '/chauffeur';
  static const String cheminAdminQr = '/admin/qrcodes';
  static const String cheminInvitationEquipe = '/admin/equipe';
  static const String cheminApkCollaborateur = '/releases/kelegance-latest.apk';
  static const String profilHubBrasDroit = 'bras_droit';
  static const String profilHubCollaborateur = 'collaborateur';

  /// Origine utilisée pour les QR imprimés : domaine courant en prod web, sinon constante.
  static String get origine {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && !host.startsWith('127.')) {
        return Uri.base.origin;
      }
    }
    return domaineProduction;
  }

  static String get reserver => '$origine$cheminReserver';
  static String get hub => '$origine$cheminHub';
  static String get hubBrasDroit => '$origine$cheminHub?profil=$profilHubBrasDroit';
  static String get hubCollaborateur => chauffeur;
  static String get gestionBrasDroit => '$origine$cheminGestion?profil=$profilHubBrasDroit';
  static String get gestion => '$origine$cheminGestion';
  static String get chauffeur => '$origine$cheminChauffeur?role=driver';
  static String get adminQrCodes => '$origine$cheminAdminQr';
  static String get invitationEquipe => '$origine$cheminInvitationEquipe';

  /// Lien sécurisé d'onboarding chauffeur collaborateur (`role=driver`).
  static String lienConnexionChauffeur({String? invite, String? email}) {
    final params = <String, String>{'role': 'driver'};
    if (invite != null && invite.isNotEmpty) params['invite'] = invite;
    if (email != null && email.isNotEmpty) params['email'] = email;
    return Uri.parse('$origine$cheminChauffeur').replace(queryParameters: params).toString();
  }
  static String get apkCollaborateur => '$origine$cheminApkCollaborateur';
  static String get apkLatest => '$origine$cheminApkCollaborateur';
  static String get webReleaseManifest => '$origine/releases/web-latest.json';

  /// Manifeste OTA Android — hébergé sur Firebase /releases/.
  static String get androidReleaseManifest => '$origine/releases/android-latest.json';
}
