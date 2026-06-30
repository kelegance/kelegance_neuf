import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'kelegance_roles.dart';
import 'kelegance_router.dart';
import 'kelegance_web_urls.dart';

/// Garde console chauffeur — Firebase Auth obligatoire + rôle professionnel.
class KeleganceConsoleChauffeurGuard extends StatefulWidget {
  const KeleganceConsoleChauffeurGuard({
    super.key,
    required this.child,
    required this.refus,
    this.ouvrirDirectement = false,
  });

  final Widget child;
  final Widget refus;
  final bool ouvrirDirectement;

  @override
  State<KeleganceConsoleChauffeurGuard> createState() => _KeleganceConsoleChauffeurGuardState();
}

class _KeleganceConsoleChauffeurGuardState extends State<KeleganceConsoleChauffeurGuard> {
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  String? _role;
  bool _resolvingRole = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _role = null;
        _resolvingRole = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _resolvingRole = true;
    });

    final role = await AuthService.resoudreRoleDepuisFirestore(user);
    if (!mounted) return;
    setState(() {
      _role = role;
      _resolvingRole = false;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1426),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }
    if (_user == null || _role != 'chauffeur') {
      return widget.refus;
    }
    return widget.child;
  }
}

/// Indique si la route web courante cible l'espace chauffeur / gestion.
bool keleganceRouteChauffeurDemandee({bool intentGestion = false}) {
  if (intentGestion) return true;
  if (!kIsWeb) return false;
  final chemin = KeleganceRouter.cheminDepuisSettings(Uri.base.path);
  return KeleganceRouter.estRouteGestionChauffeur(chemin);
}

/// `?role=driver` ou chemin `/chauffeur` — console collaborateur restreinte.
bool keleganceRouteChauffeurDriver() {
  if (!kIsWeb) return false;
  final chemin = KeleganceRouter.cheminDepuisSettings(Uri.base.path);
  final role = Uri.base.queryParameters['role']?.toLowerCase();
  if (chemin == KeleganceWebUrls.cheminChauffeur) return true;
  if (chemin == KeleganceWebUrls.cheminGestion && role == 'driver') return true;
  return false;
}

/// Garde de navigation — vérifie les droits Firestore avant d'afficher une route.
class KeleganceNavigationGuard extends StatefulWidget {
  const KeleganceNavigationGuard({
    super.key,
    required this.child,
    required this.refus,
    this.verifier,
  });

  final Widget child;
  final Widget refus;
  final Future<bool> Function()? verifier;

  @override
  State<KeleganceNavigationGuard> createState() => _KeleganceNavigationGuardState();
}

class _KeleganceNavigationGuardState extends State<KeleganceNavigationGuard> {
  late Future<bool> _autorisation;

  @override
  void initState() {
    super.initState();
    _autorisation = _evaluer();
  }

  Future<bool> _evaluer() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    await KeleganceRoles.initialiserPourUtilisateurCourant();
    if (widget.verifier != null) {
      return widget.verifier!();
    }
    return KeleganceRoles.peutAccederRoutesAdmin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _autorisation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
          );
        }
        if (snapshot.data == true) return widget.child;
        return widget.refus;
      },
    );
  }
}

/// Message standard — permission refusée.
void keleganceAfficherRefusPermission(BuildContext context, {String? detail}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.redAccent.shade700,
      duration: const Duration(seconds: 4),
      content: Text(
        detail ?? 'Accès refusé — droits Bras Droit ou Admin requis.',
      ),
    ),
  );
}

/// Vérifie la permission avant une action (bouton, navigation manuelle).
Future<bool> keleganceVerifierPermission({
  required BuildContext context,
  required bool Function() autorise,
  String? messageRefus,
}) async {
  await KeleganceRoles.initialiserPourUtilisateurCourant();
  if (autorise()) return true;
  if (context.mounted) {
    keleganceAfficherRefusPermission(context, detail: messageRefus);
  }
  return false;
}
