import 'package:flutter/foundation.dart';

import 'kelegance_web_urls.dart';

/// Routage web Kelegance (path URL strategy, sans go_router).
abstract final class KeleganceRouter {
  static const String accueil = '/';
  static const String consoleAdmin = '/console';
  static const String invitationEquipe = '/admin/equipe';

  static String routeInitiale() {
    if (!kIsWeb) return accueil;
    return cheminDepuisSettings(Uri.base.path);
  }

  static String _normaliserChemin(String path) {
    if (path.isEmpty || path == '/') return accueil;
    return path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;
  }

  static String cheminDepuisSettings(String? name) {
    return _normaliserChemin(name ?? accueil);
  }

  static bool estRouteAdmin(String path) {
    final p = _normaliserChemin(path);
    return p == KeleganceWebUrls.cheminAdminQr ||
        p == KeleganceWebUrls.cheminInvitationEquipe ||
        p.startsWith('/admin');
  }

  static bool estRouteInvitationEquipe(String path) =>
      _normaliserChemin(path) == KeleganceWebUrls.cheminInvitationEquipe;

  /// Console admin — Bras Droit uniquement (distinct de /gestion collaborateur).
  static bool estRouteConsoleAdmin(String path) {
    return _normaliserChemin(path) == consoleAdmin;
  }

  static bool estRouteGestionChauffeur(String path) {
    final p = _normaliserChemin(path);
    return p == KeleganceWebUrls.cheminGestion || p == KeleganceWebUrls.cheminChauffeur;
  }
}
