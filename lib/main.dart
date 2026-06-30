import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'auth_service.dart';
import 'firebase_options.dart';
import 'kelegance_adresse_autocomplete.dart';
import 'kelegance_console_prefs.dart';
import 'kelegance_calendrier_multi_dates.dart';
import 'kelegance_contenus.dart';
import 'kelegance_deep_link.dart';
import 'kelegance_maps_launch.dart';
import 'kelegance_bon_commande_service.dart';
import 'kelegance_bon_commande_ui.dart';
import 'kelegance_live_sync.dart';
import 'kelegance_missions_service.dart';
import 'mission_details_screen.dart';
import 'kelegance_factures_service.dart';
import 'kelegance_documents_pdf_service.dart';
import 'kelegance_ota_update.dart';
import 'kelegance_platform.dart';
import 'kelegance_dispatch_sollicitation.dart';
import 'kelegance_presence_equipe.dart';
import 'kelegance_presence_service.dart';
import 'kelegance_qr_reservation.dart';
import 'kelegance_overlay_discretion.dart';
import 'kelegance_invitation_chauffeur_ui.dart';
import 'kelegance_navigation_guard.dart';
import 'kelegance_notification_prefs_ui.dart';
import 'kelegance_roles.dart';
import 'kelegance_roles_diagnostic.dart';
import 'kelegance_router.dart';
import 'kelegance_version_check.dart';
import 'kelegance_web_urls.dart';
import 'qr_generator_page.dart';
import 'reveil_missions_service.dart';
import 'kelegance_fcm_background.dart';
import 'stripe_paiement_service.dart';
import 'utils/pricing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configurerStrategieUrlWeb();
  await KeleganceVersionCheck.verifierAuDemarrage();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Kelegance init Firebase: $e\n$st');
    }
  }

  await AuthService.configurerPersistance();
  await KeleganceDeepLink.capturerLiensEntrants();
  await _configurerRenduCarteMobile();

  if (keleganceEstAndroid) {
    await KeleganceOverlayCourse.initialiserPermissions();
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(keleganceFirebaseMessagingBackgroundHandler);
    unawaited(KeleganceAudioAlertes.initialiser());
    unawaited(KeleganceReveilMissions.initialiser());
  }

  runApp(const KeleganceApp());
}

void _configurerStrategieUrlWeb() {
  if (!kIsWeb) return;
  try {
    usePathUrlStrategy();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Kelegance URL strategy: $e\n$st');
    }
    // Repli implicite sur la stratégie hash (#/) si <base href> est invalide.
  }
}

/// Rendu carte Android — moteur le plus récent (3D / bâtiments haute qualité).
Future<void> _configurerRenduCarteMobile() async {
  if (kIsWeb || !keleganceEstAndroid) return;
  final implementation = GoogleMapsFlutterPlatform.instance;
  if (implementation is GoogleMapsFlutterAndroid) {
    await implementation.initializeWithRenderer(AndroidMapRenderer.latest);
  }
}

class KeleganceConfig {
  static const String version = '7.0.1';
  /// Affiché en bas de l'écran d'accueil — permet de vérifier le déploiement.
  static const String versionAffichage = 'v1.1.1';
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI',
  );
  static const String libelleForfaitAeroGare = 'Forfait Aéroport / Gare détecté et configuré';
  static const int capacitePassagersMax = 4;
  static const String libelleCapacitePassagers = 'Capacité : 4 passagers maximum';
  static const String emailAdmin = KeleganceIdentiteDocuments.emailAdmin;
  static const String whatsappPrestige = KeleganceIdentiteDocuments.whatsappPrestige;
  static const String exploitant = KeleganceIdentiteDocuments.exploitant;
  static const String prestationVtc = KeleganceIdentiteDocuments.prestationVtc;
  static const Color or = Color(0xFFD4AF37);
  static const Color noirProfond = Color(0xFF000000);
  static const Color minuitBleu = Color(0xFF0B1426);
  static const Color minuitBleuClair = Color(0xFF121E33);
  static const Color blancCasse = Color(0xFFF5F0E6);
  static const double rayonBoutonPremium = 10.0;
}

/// Charte visuelle premium Kelegance — v6.9.0 Élite.
abstract final class KeleganceThemePremium {
  static const Color fond = KeleganceConfig.minuitBleu;
  static const Color fondCarte = KeleganceConfig.minuitBleuClair;
  static const Color or = KeleganceConfig.or;
  static const Color textePrincipal = KeleganceConfig.blancCasse;
  static const Color texteDiscret = Color(0x99F5F0E6);

  static TextStyle titreAlerte({double size = 24}) => TextStyle(
        color: textePrincipal,
        fontSize: size,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.4,
        height: 1.2,
      );

  static TextStyle libelleNet() => const TextStyle(
        color: or,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.2,
      );

  static TextStyle montantNet({double size = 40}) => TextStyle(
        color: or,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1,
      );

  static TextStyle montantTtc() => const TextStyle(
        color: texteDiscret,
        fontSize: 13,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.4,
      );

  static ButtonStyle boutonAccept({Color? fond}) => ElevatedButton.styleFrom(
        backgroundColor: fond ?? const Color(0xFF1B5E3B),
        foregroundColor: textePrincipal,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
          side: BorderSide(color: or.withOpacity(0.45), width: 0.8),
        ),
      );

  static ButtonStyle boutonRefus() => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE57373),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
          side: const BorderSide(color: Color(0x66E57373), width: 0.8),
        ),
      );

  static Widget bandeauNetChauffeur({
    required String netText,
    required String prixText,
    String? fraisText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fondCarte, fond.withOpacity(0.92)],
        ),
        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium + 2),
        border: Border.all(color: or.withOpacity(0.42), width: 0.9),
      ),
      child: Column(
        children: [
          Text('NET CHAUFFEUR', style: libelleNet()),
          const SizedBox(height: 8),
          Text('$netText €', textAlign: TextAlign.center, style: montantNet()),
          const SizedBox(height: 12),
          Text('Total course TTC : $prixText €', textAlign: TextAlign.center, style: montantTtc()),
          if (fraisText != null) ...[
            const SizedBox(height: 4),
            Text('dont frais service 15 % : $fraisText €', textAlign: TextAlign.center, style: montantTtc()),
          ],
        ],
      ),
    );
  }
}

/// Ventilation commission Kelegance — 15 % frais service / 85 % net chauffeur.
abstract final class KeleganceCommission {
  static const double tauxFraisService = 0.15;
  static const double tauxNetChauffeur = 0.85;

  static ({double prixTotal, double fraisService, double netChauffeur}) ventiler(double prixTotal) {
    final frais = double.parse((prixTotal * tauxFraisService).toStringAsFixed(2));
    final net = double.parse((prixTotal * tauxNetChauffeur).toStringAsFixed(2));
    return (prixTotal: prixTotal, fraisService: frais, netChauffeur: net);
  }
}

/// Tri chronologique des missions — v6.1.0 (priorité temporelle croissante).
abstract final class KeleganceMissionTri {
  static DateTime? extraireHorodatage(Map<String, dynamic> data) {
    final dateRaw = data['date']?.toString().trim() ?? '';
    final heureRaw = data['heure']?.toString().trim() ?? '';
    if (dateRaw.isEmpty) return null;

    DateTime? datePart;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(dateRaw);
    if (iso != null) {
      datePart = DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(dateRaw);
    if (datePart == null && slash != null) {
      datePart = DateTime(
        int.parse(slash.group(3)!),
        int.parse(slash.group(2)!),
        int.parse(slash.group(1)!),
      );
    }
    if (datePart == null) {
      datePart = DateTime.tryParse(dateRaw.split(' ').first);
    }
    if (datePart == null) return null;

    var h = 0;
    var m = 0;
    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(heureRaw);
    if (hm != null) {
      h = int.parse(hm.group(1)!);
      m = int.parse(hm.group(2)!);
    }
    return DateTime(datePart.year, datePart.month, datePart.day, h, m);
  }

  static List<QueryDocumentSnapshot> trierChronologique(List<QueryDocumentSnapshot> docs) {
    final copy = List<QueryDocumentSnapshot>.from(docs);
    copy.sort((a, b) {
      final da = extraireHorodatage(a.data() as Map<String, dynamic>);
      final db = extraireHorodatage(b.data() as Map<String, dynamic>);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  static String formaterDateFirestore(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Communication chauffeur-client — v6.9.0 (WhatsApp Business Pro + appel direct).
abstract final class KeleganceCommunication {
  static const String _packageWhatsAppBusinessAndroid = 'com.whatsapp.w4b';
  static const String messageClientEnRoute =
      'Bonjour, votre chauffeur KELEGANCE est en route vers vous';
  static const String messageClientSurPlace =
      'Bonjour, votre chauffeur KELEGANCE est arrivé à votre point de rendez-vous';
  static final RegExp _chiffresSeuls = RegExp(r'\D');

  static String messageProChauffeur({String? complement}) {
    if (complement != null && complement.isNotEmpty) {
      return complement;
    }
    return 'Bonjour,';
  }

  static bool _ressembleNumero(String texte) {
    final digits = texte.replaceAll(_chiffresSeuls, '');
    return digits.length >= 8 && !texte.contains('@');
  }

  static String? extraireNumeroMission(Map<String, dynamic> data) {
    for (final cle in ['phone', 'telephone', 'tel', 'clientPhone', 'mobile']) {
      final valeur = data[cle]?.toString().trim();
      if (valeur != null && valeur.isNotEmpty && _ressembleNumero(valeur)) return valeur;
    }
    final client = data['client']?.toString().trim() ?? '';
    if (_ressembleNumero(client)) return client;
    return null;
  }

  static String normaliserWhatsApp(String numero) {
    var digits = numero.replaceAll(_chiffresSeuls, '');
    if (digits.startsWith('0') && digits.length == 10) {
      digits = '33${digits.substring(1)}';
    } else if (digits.length == 9 && !digits.startsWith('33')) {
      digits = '33$digits';
    }
    return digits;
  }

  static String normaliserTel(String numero) {
    final digits = numero.replaceAll(_chiffresSeuls, '');
    if (digits.startsWith('33') && digits.length >= 11) return '+$digits';
    if (digits.startsWith('0') && digits.length == 10) return '+33${digits.substring(1)}';
    if (digits.length >= 8) return '+$digits';
    return numero.trim();
  }

  static Future<String?> resoudreNumeroClient(Map<String, dynamic> data) async {
    final direct = extraireNumeroMission(data);
    if (direct != null) return direct;

    final emailCandidate = data['email']?.toString().trim().toLowerCase();
    final clientCandidate = data['client']?.toString().trim().toLowerCase();
    final email = (emailCandidate != null && emailCandidate.contains('@'))
        ? emailCandidate
        : (clientCandidate != null && clientCandidate.contains('@') ? clientCandidate : null);

    if (email == null) return null;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final phone = snap.docs.first.data()['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty && _ressembleNumero(phone)) return phone;
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceCommunication résolution tel: $e');
    }
    return null;
  }

  static Future<void> ouvrirWhatsApp(
    BuildContext context,
    String numero, {
    String? message,
  }) async {
    final wa = normaliserWhatsApp(numero);
    final texte = message ?? messageProChauffeur();
    final textEncoded = Uri.encodeComponent(texte);
    try {
      if (keleganceEstAndroid) {
        final intentBusiness = Uri.parse(
          'intent://send?phone=$wa&text=$textEncoded#Intent;scheme=whatsapp;package=$_packageWhatsAppBusinessAndroid;end',
        );
        if (await canLaunchUrl(intentBusiness)) {
          await launchUrl(intentBusiness, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (keleganceEstIOS) {
        final businessNatif = Uri.parse('whatsapp-business://send?phone=$wa&text=$textEncoded');
        if (await canLaunchUrl(businessNatif)) {
          await launchUrl(businessNatif, mode: LaunchMode.externalApplication);
          return;
        }
      }

      final natif = Uri.parse('whatsapp://send?phone=$wa&text=$textEncoded');
      if (await canLaunchUrl(natif)) {
        await launchUrl(natif, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(
        Uri.parse('https://wa.me/$wa?text=$textEncoded'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Impossible d\'ouvrir WhatsApp Business : $e'),
        ),
      );
    }
  }

  static Future<void> ouvrirAppel(BuildContext context, String numero) async {
    final tel = normaliserTel(numero);
    try {
      await launchUrl(Uri.parse('tel:$tel'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Impossible d\'ouvrir le numéroteur : $e'),
        ),
      );
    }
  }
}

/// Document client partageable via lien web Kelegance unique — facturation 100 % électronique.
class KeleganceDocumentPartage {
  const KeleganceDocumentPartage({
    required this.token,
    required this.lienWeb,
    required this.type,
    required this.titre,
    this.missionId,
    this.htmlContenu,
    this.numeroDocument,
    this.emailDestinataire,
  });

  final String token;
  final String lienWeb;
  final String type;
  final String titre;
  final String? missionId;
  final String? htmlContenu;
  final String? numeroDocument;
  final String? emailDestinataire;

  String get messagePartage =>
      'Kelegance Prestige — $titre\nConsultez votre document électronique en ligne :\n$lienWeb';
}

/// Module miroir BDC retour & Facture TTC — publication Firestore + partage SMS / WhatsApp Business.
abstract final class KeleganceDocumentsClient {
  static const String baseUrlWeb = 'https://kelegance.web.app/doc';
  static const String collection = 'documents_client';

  static String genererToken() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'KDC-${ts.toRadixString(36).toUpperCase()}-${(ts % 9999).toString().padLeft(4, '0')}';
  }

  static String construireLienWeb(String token) => '$baseUrlWeb/$token';

  static Future<KeleganceDocumentPartage> publier({
    required String type,
    required Map<String, dynamic> missionData,
    String? missionId,
    String? numeroDocument,
  }) async {
    final token = genererToken();
    final lien = construireLienWeb(token);
    final prix = (missionData['prix'] as num?)?.toDouble() ?? 0.0;
    final ventilation = KeleganceCommission.ventiler(prix);
    final titre = switch (type) {
      'BON DE COMMANDE RETOUR' => 'Bon de commande retour',
      'BON DE COMMANDE VTC' => 'Bon de commande VTC',
      _ => 'Facture TTC',
    };

    final donnees = KeleganceDocumentDonnees.depuisMission(
      missionData,
      type: type,
      token: token,
      numeroDocument: numeroDocument,
      missionId: missionId,
    );
    final htmlContenu = KeleganceDocumentsPdfService.genererHtml(type: type, donnees: donnees);

    await FirebaseFirestore.instance.collection(collection).doc(token).set({
      'token': token,
      'type': type,
      'titre': titre,
      'lienWeb': lien,
      'missionId': missionId,
      'client': missionData['client'] ?? '',
      'email': missionData['email'] ?? missionData['client'] ?? '',
      'depart': missionData['depart'] ?? '',
      'destination': missionData['destination'] ?? '',
      'date': missionData['date'] ?? '',
      'heure': missionData['heure'] ?? '',
      'passagers': donnees.passagers,
      'prixTtc': prix,
      'prixHt': donnees.prixHt,
      'tva': donnees.tva,
      'netChauffeur': ventilation.netChauffeur,
      'fraisService': ventilation.fraisService,
      'numeroDocument': donnees.numeroDocument,
      'dateEmission': donnees.dateEmission,
      'htmlContenu': htmlContenu,
      'format': 'electronique_web',
      'emailAdmin': KeleganceIdentiteDocuments.emailAdmin,
      'whatsappPrestige': KeleganceIdentiteDocuments.whatsappPrestige,
      'statut': 'publie',
      'source': 'console_chauffeur_v701',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return KeleganceDocumentPartage(
      token: token,
      lienWeb: lien,
      type: type,
      titre: titre,
      missionId: missionId,
      htmlContenu: htmlContenu,
      numeroDocument: donnees.numeroDocument,
      emailDestinataire: missionData['email']?.toString(),
    );
  }

  static Future<KeleganceDocumentPartage> genererBonCommandeRetour(
    Map<String, dynamic> missionData, {
    String? missionId,
  }) =>
      publier(type: 'BON DE COMMANDE RETOUR', missionData: missionData, missionId: missionId);

  static Future<KeleganceDocumentPartage> genererFactureTtc(
    Map<String, dynamic> missionData, {
    String? missionId,
  }) async {
    final doc = await publier(type: 'FACTURE TTC', missionData: missionData, missionId: missionId);
    final numero = 'FAC-${DateTime.now().year}-${doc.token.substring(4, 12)}';
    await FirebaseFirestore.instance.collection('factures').add({
      'numero': numero,
      'client': missionData['client'] ?? 'CLIENT INCONNU',
      'email': missionData['email'] ?? '',
      'montant': ((missionData['prix'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
      'date':
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
      'statut': 'PUBLIÉ',
      'lienWeb': doc.lienWeb,
      'tokenDocument': doc.token,
      'source': 'CONSOLE_CHAUFFEUR_V701',
    });
    return doc;
  }

  static Future<void> partagerParSms(BuildContext context, String numero, KeleganceDocumentPartage doc) async {
    final msg = Uri.encodeComponent(doc.messagePartage);
    final tel = normaliserTelSms(numero);
    try {
      await launchUrl(Uri.parse('sms:$tel?body=$msg'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.orange, content: Text('Impossible d\'ouvrir SMS : $e')),
      );
    }
  }

  static String normaliserTelSms(String numero) {
    final digits = numero.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 10) return '+33${digits.substring(1)}';
    if (digits.startsWith('33')) return '+$digits';
    return digits.startsWith('+') ? numero.trim() : '+$digits';
  }

  static Future<void> partagerParWhatsAppBusiness(
    BuildContext context,
    String numero,
    KeleganceDocumentPartage doc,
  ) =>
      KeleganceCommunication.ouvrirWhatsApp(context, numero, message: doc.messagePartage);

  static Future<void> partagerLien(BuildContext context, KeleganceDocumentPartage doc) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Kelegance Prestige — ${doc.titre}',
          text: doc.messagePartage,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.orange, content: Text('Partage impossible : $e')),
      );
    }
  }

  static Future<void> envoyerLienParEmail(
    BuildContext context,
    KeleganceDocumentPartage doc, {
    String? destinataire,
  }) async {
    final to = (destinataire ?? doc.emailDestinataire ?? '').trim();
    final subject = Uri.encodeComponent('Kelegance Prestige — ${doc.titre}');
    final body = Uri.encodeComponent(doc.messagePartage);
    final uri = to.isNotEmpty
        ? Uri.parse('mailto:$to?subject=$subject&body=$body')
        : Uri.parse('mailto:?subject=$subject&body=$body');
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Aucune application e-mail disponible sur cet appareil.'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.orange, content: Text('Envoi e-mail impossible : $e')),
      );
    }
  }

  static KeleganceDocumentPartage depuisFacture(Map<String, dynamic> data) {
    final lien = data['lienWeb']?.toString() ?? '';
    final token = data['tokenDocument']?.toString() ?? '';
    final numero = data['numero']?.toString() ?? 'Facture';
    return KeleganceDocumentPartage(
      token: token,
      lienWeb: lien,
      type: 'FACTURE TTC',
      titre: 'Facture $numero',
      numeroDocument: numero,
      emailDestinataire: data['email']?.toString() ?? data['client']?.toString(),
    );
  }

  static Future<void> afficherFeuillePartage(
    BuildContext context, {
    required KeleganceDocumentPartage document,
    String? telephone,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KeleganceConfig.minuitBleu,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: KeleganceConfig.or.withOpacity(0.55), width: 0.8),
      ),
      builder: (ctx) {
        final tel = telephone;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(document.titre, style: KeleganceThemePremium.titreAlerte(size: 16)),
              const SizedBox(height: 8),
              Text(
                'Facture électronique — consultation web sécurisée',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
              ),
              const SizedBox(height: 6),
              SelectableText(
                document.lienWeb,
                style: const TextStyle(color: KeleganceConfig.or, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: KeleganceConfig.or,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text(
                    'Partager le lien',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    unawaited(partagerLien(context, document));
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: KeleganceConfig.or.withOpacity(0.55)),
                    foregroundColor: KeleganceConfig.or,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                    ),
                  ),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text(
                    'Envoyer par e-mail',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    unawaited(envoyerLienParEmail(context, document));
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (tel != null && tel.isNotEmpty) ...[
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green.withOpacity(0.65)),
                      foregroundColor: const Color(0xFF81C784),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                      ),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('WhatsApp Business Pro', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(partagerParWhatsAppBusiness(context, tel, document));
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: KeleganceConfig.or.withOpacity(0.55)),
                      foregroundColor: KeleganceConfig.or,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                      ),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Envoyer par SMS', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(partagerParSms(context, tel, document));
                    },
                  ),
                ),
              ] else
                Text(
                  'Numéro client indisponible — copiez le lien ci-dessus pour le transmettre.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Extraction macro des adresses pour alerte chauffeur (sans rue précise).
abstract final class KeleganceAdresse {
  static String extraireVille(String adresse) {
    final texte = adresse.trim();
    if (texte.isEmpty) return '—';

    final segments = texte.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      final dernier = segments.last;
      final codePostal = RegExp(r'\b\d{5}\b').firstMatch(dernier);
      if (codePostal != null) {
        final ville = dernier.replaceAll(codePostal.group(0)!, '').trim();
        if (ville.isNotEmpty) return ville;
      }
      return dernier;
    }

    final matchCp = RegExp(r'\b(\d{5})\s+(.+)$').firstMatch(texte);
    if (matchCp != null) return matchCp.group(2)!.trim();

    return texte;
  }

  static String formaterDestinationMacro(String destination) {
    final t = destination.toLowerCase();
    if (t.contains('cdg') || t.contains('roissy') || t.contains('gaulle') || t.contains('charles')) {
      return 'Aéroport Roissy CDG';
    }
    if (t.contains('orly') || t.contains('ory')) return 'Aéroport Orly';
    if (t.contains('beauvais') || t.contains('bva') || t.contains('tillé') || t.contains('tille')) {
      return 'Aéroport Beauvais';
    }
    if (t.contains('montparnasse')) return 'Gare Montparnasse';
    if (t.contains('saint-lazare') || t.contains('st lazare')) return 'Gare Saint-Lazare';
    if (t.contains('gare de lyon') || (t.contains('gare') && t.contains('lyon'))) return 'Gare de Lyon';
    if (t.contains('gare du nord') || (t.contains('gare') && t.contains('nord'))) return 'Gare du Nord';
    if (t.contains('austerlitz')) return 'Gare d\'Austerlitz';
    if (t.contains('bercy')) return 'Gare de Bercy';
    if (t.contains('gare de l\'est') || (t.contains('gare') && t.contains('est'))) return 'Gare de l\'Est';
    if (t.contains('rungis') || t.contains('marché international') || t.contains('marche international')) {
      return 'Marché International de Rungis';
    }
    if (t.contains('gare')) return 'Gare parisienne';

    final ville = extraireVille(destination);
    return ville.isNotEmpty ? ville : destination.trim();
  }
}

/// Gestion complète des réservations — v7.0.0 Élite (Modifier, Dispatch, Valider, Annuler, escales).
abstract final class KeleganceGestionReservations {
  static String formaterItineraire(Map<String, dynamic> data) {
    final depart = data['depart']?.toString() ?? '';
    final destination = data['destination']?.toString() ?? '';
    final escalesRaw = data['escales'];
    final escales = escalesRaw is List
        ? escalesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    if (escales.isEmpty) return '$depart ➔ $destination';
    return '$depart ➔ ${escales.join(' ➔ ')} ➔ $destination';
  }

  static bool actionsBloquees(Map<String, dynamic> data) {
    final statut = (data['statut']?.toString() ?? '').toUpperCase().replaceAll('É', 'E').trim();
    return statut == 'EN COURSE' ||
        statut == 'SUR PLACE' ||
        statut == 'EN_ROUTE' ||
        statut == 'EN ROUTE' ||
        statut == 'TERMINE' ||
        statut == 'ANNULE';
  }

  static Future<void> valider(String docId) async {
    await FirebaseFirestore.instance.collection('missions').doc(docId).update({'statut': 'PLANIFIÉ'});
  }

  static Future<void> annuler(String docId) async {
    await FirebaseFirestore.instance.collection('missions').doc(docId).update({'statut': 'ANNULÉ'});
  }

  static void afficherModifier(BuildContext context, String docId, Map<String, dynamic> data) {
    final dateCtrl = TextEditingController(text: data['date']?.toString() ?? '');
    final heureCtrl = TextEditingController(text: data['heure']?.toString() ?? '');
    final departCtrl = TextEditingController(text: data['depart']?.toString() ?? '');
    final destCtrl = TextEditingController(text: data['destination']?.toString() ?? '');
    final noteCtrl = TextEditingController(text: data['note']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Modifier la réservation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Date', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: heureCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Heure', labelStyle: TextStyle(color: Colors.white60)),
              ),
              KeleganceAdresseAutocomplete(
                controller: departCtrl,
                labelText: 'Lieu de prise en charge',
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Lieu de prise en charge', labelStyle: TextStyle(color: Colors.white60)),
              ),
              KeleganceAdresseAutocomplete(
                controller: destCtrl,
                labelText: 'Destination',
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Destination', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note / instructions', labelStyle: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('missions').doc(docId).update({
                'date': dateCtrl.text.trim(),
                'heure': heureCtrl.text.trim(),
                'depart': departCtrl.text.trim(),
                'destination': destCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'modifieLe': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('Réservation mise à jour.')),
                );
              }
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void afficherAjouterPoint(BuildContext context, String docId, Map<String, dynamic> data) {
    final escaleCtrl = TextEditingController();
    final escalesExistantes = data['escales'] is List
        ? (data['escales'] as List).map((e) => e.toString()).toList()
        : <String>[];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Ajouter un point', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (escalesExistantes.isNotEmpty) ...[
              Text(
                'Escales actuelles : ${escalesExistantes.join(' → ')}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 10),
            ],
            KeleganceAdresseAutocomplete(
              controller: escaleCtrl,
              labelText: 'Nouvelle escale / étape',
              hintText: 'Adresse intermédiaire',
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nouvelle escale / étape',
                hintText: 'Adresse intermédiaire',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              final nouvelle = escaleCtrl.text.trim();
              if (nouvelle.isEmpty) return;
              final maj = [...escalesExistantes, nouvelle];
              await FirebaseFirestore.instance.collection('missions').doc(docId).update({
                'escales': maj,
                'modifieLe': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('Point ajouté à l\'itinéraire.')),
                );
              }
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void afficherDispatch(BuildContext context, String docId, Map<String, dynamic> data) {
    final departCtrl = TextEditingController(text: data['depart']?.toString() ?? '');
    final destCtrl = TextEditingController(text: data['destination']?.toString() ?? '');
    final chauffeurCtrl = TextEditingController(text: data['chauffeurAssigne']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Dispatch — attribuer la course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modifier l\'itinéraire si nécessaire :', style: TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 8),
              KeleganceAdresseAutocomplete(
                controller: departCtrl,
                labelText: 'Lieu de prise en charge',
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Lieu de prise en charge', labelStyle: TextStyle(color: Colors.white60)),
              ),
              KeleganceAdresseAutocomplete(
                controller: destCtrl,
                labelText: 'Destination',
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Destination', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const Divider(color: Colors.white24, height: 24),
              const Text('Attribuer à un chauffeur / partenaire :', style: TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: chauffeurCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nom ou e-mail du chauffeur',
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              final chauffeur = chauffeurCtrl.text.trim();
              await FirebaseFirestore.instance.collection('missions').doc(docId).update({
                'depart': departCtrl.text.trim(),
                'destination': destCtrl.text.trim(),
                if (chauffeur.isNotEmpty) 'chauffeurAssigne': chauffeur,
                'statut': 'REDISPATCHÉ',
                'dispatcheLe': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course dispatchée — en attente de prise en charge.')),
                );
              }
            },
            child: const Text('Dispatch', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget barreActions({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    bool bloque = false,
    bool accesComplet = true,
    double fontSize = 11,
  }) {
    if (!accesComplet) return const SizedBox.shrink();
    final verrou = bloque || actionsBloquees(data);
    Color couleur(bool actif, Color couleurActive) => actif ? couleurActive : Colors.white24;

    return Wrap(
      spacing: 4,
      runSpacing: 5,
      children: [
        TextButton.icon(
          onPressed: verrou ? null : () => afficherModifier(context, docId, data),
          icon: Icon(Icons.edit_outlined, color: couleur(!verrou, Colors.amber), size: 16),
          label: Text('Modifier', style: TextStyle(color: couleur(!verrou, Colors.amber), fontSize: fontSize, fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: verrou ? null : () => afficherAjouterPoint(context, docId, data),
          icon: Icon(Icons.add_location_alt_outlined, color: couleur(!verrou, Colors.tealAccent), size: 16),
          label: Text('Ajouter un point', style: TextStyle(color: couleur(!verrou, Colors.tealAccent), fontSize: fontSize, fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: verrou ? null : () => afficherDispatch(context, docId, data),
          icon: Icon(Icons.shuffle, color: couleur(!verrou, Colors.blue), size: 16),
          label: Text('Dispatch', style: TextStyle(color: couleur(!verrou, Colors.blue), fontSize: fontSize, fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: verrou ? null : () async => await valider(docId),
          icon: Icon(Icons.check_circle, color: couleur(!verrou, Colors.green), size: 16),
          label: Text('Valider', style: TextStyle(color: couleur(!verrou, Colors.green), fontSize: fontSize, fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: verrou ? null : () async => await annuler(docId),
          icon: Icon(Icons.cancel, color: couleur(!verrou, Colors.redAccent), size: 16),
          label: Text('Annuler', style: TextStyle(color: couleur(!verrou, Colors.redAccent), fontSize: fontSize, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Alertes audio chauffeur — v4.8.0 (boucle stricte + logs diagnostic terminal).
abstract final class KeleganceAudioAlertes {
  static final AudioPlayer _instantPlayer = AudioPlayer(playerId: 'kelegance_instant');
  static final AudioPlayer _notificationPlayer = AudioPlayer(playerId: 'kelegance_notif');
  static const String _sonCourse = 'sounds/course_instantanee.mp3';
  static const String _sonNotification = 'sounds/alerte_notification.mp3';
  static const double _vitesseCourseInstantanee = 1.2;
  static double _volumeAlerte = 1.0;
  static bool _initialise = false;
  static bool _boucleInstantActive = false;
  static StreamSubscription<void>? _finInstantSub;

  static AudioPlayer get audioPlayer => _instantPlayer;

  static void definirVolumeAlerte(double volume) {
    _volumeAlerte = volume.clamp(0.0, 1.0);
    unawaited(_instantPlayer.setVolume(_volumeAlerte));
  }

  static Future<void> _configurerLecteurInstant() async {
    await audioPlayer.setPlaybackRate(_vitesseCourseInstantanee);
    await audioPlayer.setVolume(_volumeAlerte);
  }

  static Future<void> _jouerSecurise(AudioPlayer player, AssetSource source, {required String label}) async {
    try {
      await player.play(source);
      print('👉 AUDIO OK [$label] : ${source.path}');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> initialiser() async {
    if (_initialise) return;
    try {
      await _finInstantSub?.cancel();
      await _configurerLecteurInstant();
      _finInstantSub = audioPlayer.onPlayerComplete.listen((_) async {
        if (!_boucleInstantActive) return;
        try {
          await _configurerLecteurInstant();
          await audioPlayer.play(AssetSource(_sonCourse));
        } catch (e) {
          print('👉 ERREUR AUDIO CRITIQUE : $e');
        }
      });
      _initialise = true;
      print('👉 AUDIO OK : KeleganceAudioAlertes initialisé');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> playInstantRequestSound() async {
    try {
      await initialiser();
      _boucleInstantActive = true;
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _configurerLecteurInstant();
      await _jouerSecurise(audioPlayer, AssetSource(_sonCourse), label: 'course instantanée');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> stopInstantRequestSound() async {
    try {
      _boucleInstantActive = false;
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.release);
      print('👉 AUDIO OK : son course arrêté');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> playNotificationSound() async {
    try {
      await initialiser();
      await _notificationPlayer.stop();
      await _notificationPlayer.setReleaseMode(ReleaseMode.release);
      await _jouerSecurise(_notificationPlayer, AssetSource(_sonNotification), label: 'notification');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }

  static Future<void> liberer() async {
    try {
      _boucleInstantActive = false;
      await audioPlayer.stop();
      await _notificationPlayer.stop();
      print('👉 AUDIO OK : sons arrêtés (lecteur global conservé)');
    } catch (e) {
      print('👉 ERREUR AUDIO CRITIQUE : $e');
    }
  }
}

/// Style carte Google sombre — accents or Kelegance (v2.8.0).
abstract final class KeleganceCarteStyle {
  static const String sombreOr = '''
[
  {"elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#c9a227"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#000000"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#2a2418"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#141414"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#d4af37","weight":1}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1f1a10"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffc107","weight":1}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#030303"}]}
]
''';
}

/// Bloque le geste retour système — la session reste active jusqu'à déconnexion explicite.
class KeleganceEcranProtege extends StatelessWidget {
  final Widget child;

  const KeleganceEcranProtege({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: child,
    );
  }
}

class KeleganceApp extends StatelessWidget {
  const KeleganceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => KeleganceOverlayDiscretion(
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: KeleganceConfig.or,
        scaffoldBackgroundColor: KeleganceConfig.minuitBleu,
        canvasColor: KeleganceConfig.minuitBleu,
        colorScheme: const ColorScheme.dark(
          primary: KeleganceConfig.or,
          onPrimary: KeleganceConfig.noirProfond,
          secondary: KeleganceConfig.or,
          surface: KeleganceConfig.minuitBleu,
          onSurface: KeleganceConfig.blancCasse,
          background: KeleganceConfig.minuitBleu,
          onBackground: KeleganceConfig.blancCasse,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: KeleganceConfig.minuitBleu,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: KeleganceConfig.minuitBleuClair,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: KeleganceConfig.minuitBleuClair,
        ),
      ),
      initialRoute: KeleganceRouter.routeInitiale(),
      onGenerateRoute: (settings) {
        final chemin = KeleganceRouter.cheminDepuisSettings(settings.name);
        if (KeleganceRouter.estRouteAdmin(chemin)) {
          if (KeleganceRouter.estRouteInvitationEquipe(chemin)) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => KeleganceNavigationGuard(
                refus: const KeleganceAuthGate(),
                child: const KeleganceEcranProtege(child: KelegancePageInvitationEquipe()),
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => KeleganceNavigationGuard(
              refus: const KeleganceAuthGate(),
              child: const KeleganceEcranProtege(child: QrGeneratorPage()),
            ),
          );
        }
        if (KeleganceRouter.estRouteConsoleAdmin(chemin)) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => KeleganceNavigationGuard(
              refus: const KeleganceAuthGate(),
              child: KeleganceConsoleChauffeurGuard(
                refus: const PageLoginConsole(intentGestion: true),
                child: const KeleganceEcranProtege(child: PageConsole()),
              ),
            ),
          );
        }
        if (KeleganceRouter.estRouteGestionChauffeur(chemin)) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const KeleganceAuthGate(),
          );
        }
        switch (chemin) {
          case KeleganceRouter.accueil:
          default:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const KeleganceAuthGate(),
            );
        }
      },
    );
  }
}

/// v3.0.0 — Session persistante, routage auto client / chauffeur.
class KeleganceAuthGate extends StatefulWidget {
  const KeleganceAuthGate({super.key});

  @override
  State<KeleganceAuthGate> createState() => _KeleganceAuthGateState();
}

class _KeleganceAuthGateState extends State<KeleganceAuthGate> {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  String? _role;
  bool _resolvingRole = true;
  bool _ouvrirReservationClient = false;
  bool _ouvrirConsoleGestion = false;
  bool _ouvrirConsoleAdmin = false;
  bool _afficherRefusAccesAdmin = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.user.listen(_onAuthStateChanged);
    _chargerIntentsEntrants();
    if (KeleganceOtaUpdate.disponible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(KeleganceOtaUpdate.verifierAuDemarrage(context));
      });
    }
  }

  Future<void> _chargerIntentsEntrants() async {
    final reservation = await KeleganceDeepLink.aIntentReservationEnAttente();
    final gestion = await KeleganceDeepLink.aIntentGestionEnAttente();
    final consoleAdmin = await KeleganceDeepLink.aIntentConsoleAdminEnAttente();
    if (!mounted) return;
    if (!reservation && !gestion && !consoleAdmin) return;
    setState(() {
      if (reservation) _ouvrirReservationClient = true;
      if (gestion) _ouvrirConsoleGestion = true;
      if (consoleAdmin) _ouvrirConsoleAdmin = true;
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      await keleganceSynchroniserServicesLiveAvecAuth(null);
      if (!mounted) return;
      setState(() {
        _user = null;
        _role = null;
        _resolvingRole = false;
      });
      return;
    }

    await keleganceSynchroniserServicesLiveAvecAuth(user);
    if (!kIsWeb) {
      unawaited(KeleganceReveilMissions.demarrerSynchronisationFirestore());
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _resolvingRole = true;
    });

    final role = await AuthService.resoudreRoleDepuisFirestore(user);
    if (!mounted) return;
    if (role == 'chauffeur') {
      await KeleganceRoles.initialiserPourUtilisateurCourant();
    }
    var ouvrirReservation = _ouvrirReservationClient;
    var ouvrirGestion = _ouvrirConsoleGestion;
    var refusAdmin = false;

    if (_ouvrirConsoleAdmin) {
      await KeleganceDeepLink.consommerIntentConsoleAdmin();
      if (KeleganceRoles.peutAccederRoutesAdmin() && role == 'chauffeur') {
        ouvrirGestion = true;
      } else {
        refusAdmin = true;
        ouvrirGestion = false;
      }
    } else if (role != 'chauffeur') {
      ouvrirReservation = ouvrirReservation || await KeleganceDeepLink.aIntentReservationEnAttente();
      ouvrirGestion = false;
    } else {
      ouvrirGestion = ouvrirGestion || await KeleganceDeepLink.aIntentGestionEnAttente();
      ouvrirReservation = false;
    }
    setState(() {
      _role = role;
      _resolvingRole = false;
      _ouvrirReservationClient = ouvrirReservation;
      _ouvrirConsoleGestion = ouvrirGestion;
      _ouvrirConsoleAdmin = false;
      _afficherRefusAccesAdmin = refusAdmin;
    });
    if (refusAdmin && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        keleganceAfficherRefusPermission(
          context,
          detail: 'Accès /console ou /admin refusé — réservé aux Bras Droit.',
        );
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null && _resolvingRole) {
      return const Scaffold(
        backgroundColor: KeleganceConfig.minuitBleu,
        body: Center(child: CircularProgressIndicator(color: KeleganceConfig.or)),
      );
    }
    if (_user == null) {
      return PageSalon(
        intentReservation: _ouvrirReservationClient,
        intentGestion: _ouvrirConsoleGestion || keleganceRouteChauffeurDemandee(),
      );
    }
    final accesChauffeurRequis =
        keleganceRouteChauffeurDemandee(intentGestion: _ouvrirConsoleGestion);
    if (accesChauffeurRequis && _role != 'chauffeur') {
      return const PageLoginConsole(intentGestion: true);
    }
    if (_role == 'chauffeur') {
      final vueRestreinte = keleganceRouteChauffeurDriver();
      return KeleganceConsoleChauffeurGuard(
        refus: const PageLoginConsole(intentGestion: true),
        child: KeleganceEcranProtege(
          child: PageConsole(
            ouvrirDirectement: _ouvrirConsoleGestion,
            forceVueChauffeurRestreinte: vueRestreinte,
          ),
        ),
      );
    }
    return KeleganceEcranProtege(
      child: PageClient(ouvrirOngletReservation: _ouvrirReservationClient),
    );
  }
}

// ==========================================
// 1. PAGE SALON (ACCÈS GÉNÉRAL)
// ==========================================
class PageSalon extends StatefulWidget {
  final bool intentReservation;
  final bool intentGestion;

  const PageSalon({
    super.key,
    this.intentReservation = false,
    this.intentGestion = false,
  });

  @override
  _PageSalonState createState() => _PageSalonState();
}

class _PageSalonState extends State<PageSalon> {
  bool _rememberMe = false;
  
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.intentGestion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PageLoginConsole(intentGestion: true)),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _connecterUtilisateur() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _afficherMessage("Veuillez remplir tous les champs", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    var user = await _authService.signInWithEmailAndPassword(email, password);
    setState(() => _isLoading = false);

    if (user != null) {
      await AuthService.orienterSessionApresConnexion(user);
      if (!mounted) return;
      _afficherMessage("Connexion réussie !", Colors.green);
    } else {
      _afficherMessage("Échec de la connexion. Vérifiez votre email et mot de passe.", Colors.red);
    }
  }

  void _creerCompteUtilisateur() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _afficherMessage("Veuillez remplir tous les champs", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    var user = await _authService.registerWithEmailAndPassword(email, password);
    setState(() => _isLoading = false);

    if (user != null) {
      await AuthService.orienterSessionApresConnexion(user);
      if (!mounted) return;
      _afficherMessage("Compte créé avec succès !", Colors.green);
    } else {
      _afficherMessage("Échec de l'inscription. L'email est déjà utilisé ou mot de passe trop court.", Colors.red);
    }
  }

  void _afficherMessage(String message, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [KeleganceConfig.minuitBleu, KeleganceConfig.minuitBleuClair],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                children: [
                  const SizedBox(height: 60), 
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 70),
                  const Text("KELEGANCE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6, color: Colors.amber)),
                  const SizedBox(height: 8),
                  Text(
                    'Spécialiste Transferts Gares & Aéroports',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KeleganceConfig.or.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Nouveau chez Kelegance ?", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 50), 
                  if (widget.intentReservation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.35)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.map_outlined, color: Colors.amber, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connectez-vous pour accéder à la réservation Kelegance.',
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.intentGestion && !widget.intentReservation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: KeleganceConfig.minuitBleuClair,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KeleganceConfig.or.withOpacity(0.35)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.badge_outlined, color: KeleganceConfig.or, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connectez-vous pour accéder à votre espace chauffeur.',
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        _field("Email", Icons.email, controller: _emailController),
                        const SizedBox(height: 15),
                        _field("Mot de passe", Icons.lock, controller: _passwordController, obs: true),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe, 
                              activeColor: Colors.amber, 
                              onChanged: (v) => setState(() => _rememberMe = v!)
                            ),
                            const Text("Se souvenir de moi", style: TextStyle(fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isLoading 
                          ? const CircularProgressIndicator(color: Colors.amber)
                          : _btn("SE CONNECTER", Colors.amber, Colors.black, _connecterUtilisateur),
                        const SizedBox(height: 15),
                        _btn("CRÉER UN COMPTE", Colors.transparent, Colors.amber, _creerCompteUtilisateur, border: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PageLoginConsole())), 
                    child: const Text("ACCÈS CHAUFFEUR PARTENAIRE", style: TextStyle(color: Colors.white10, fontSize: 10))
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 28),
                ],
              ),
            ),
          ),
        ),
      ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  KeleganceConfig.versionAffichage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.28),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String h, IconData i, {required TextEditingController controller, bool obs = false}) => TextField(controller: controller, obscureText: obs, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.amber, size: 20), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  Widget _btn(String t, Color bg, Color tx, VoidCallback f, {bool border = false}) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: bg, minimumSize: const Size(double.infinity, 55), side: border ? const BorderSide(color: Colors.amber) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: f, child: Text(t, style: TextStyle(color: tx, fontWeight: FontWeight.bold)));
}

// ==========================================
// 2. PAGE LOGIN CONDUCTEUR (SÉCURISÉE & ANTI-OVERFLOW)
// ==========================================
class PageLoginConsole extends StatefulWidget {
  final bool intentGestion;

  const PageLoginConsole({super.key, this.intentGestion = false});
  @override
  _PageLoginConsoleState createState() => _PageLoginConsoleState();
}

class _PageLoginConsoleState extends State<PageLoginConsole> {
  bool _rememberPro = true;
  final AuthService _authService = AuthService();
  final TextEditingController _proEmailController = TextEditingController();
  final TextEditingController _proPasswordController = TextEditingController();
  bool _isProLoading = false;
  String? _tokenInvitation;

  @override
  void initState() {
    super.initState();
    _chargerInvitationDepuisUrl();
  }

  void _chargerInvitationDepuisUrl() {
    if (!kIsWeb) return;
    final invite = Uri.base.queryParameters['invite']?.trim();
    final email = Uri.base.queryParameters['email']?.trim();
    if (invite != null && invite.isNotEmpty) _tokenInvitation = invite;
    if (email != null && email.isNotEmpty) {
      _proEmailController.text = email;
    }
  }

  @override
  void dispose() {
    _proEmailController.dispose();
    _proPasswordController.dispose();
    super.dispose();
  }

  void _connecterChauffeur() async {
    final email = _proEmailController.text.trim();
    final password = _proPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir vos identifiants professionnels"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProLoading = true);
    var user = await _authService.signInWithEmailAndPassword(email, password);
    setState(() => _isProLoading = false);

    if (user != null) {
      await AuthService.declarerProfilChauffeur(user, tokenInvitation: _tokenInvitation);
      if (!mounted) return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Identifiants professionnels incorrects"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeleganceConfig.minuitBleu,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber), 
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const Text("ESPACE\nPROFESSIONNEL", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 40),
              _fieldPro("Email professionnel", Icons.badge, controller: _proEmailController),
              const SizedBox(height: 20),
              _fieldPro("Mot de passe", Icons.lock, obs: true, controller: _proPasswordController),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _rememberPro, 
                    activeColor: Colors.amber, 
                    onChanged: (v) => setState(() => _rememberPro = v!)
                  ),
                  const Text("Maintenir la session professionnelle", style: TextStyle(fontSize: 12, color: Colors.white60)),
                ]
              ),
              const SizedBox(height: 40), 
              _isProLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber, 
                        minimumSize: const Size(double.infinity, 60), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: _connecterChauffeur, 
                      child: const Text("OUVRIR MA SESSION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                    ),
              const SizedBox(height: 20),
            ]
          ),
        ),
      ),
    );
  }

  Widget _fieldPro(String h, IconData i, {required TextEditingController controller, bool obs = false}) => TextField(controller: controller, obscureText: obs, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.amber), enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber))));
}

// ==========================================
// 3. DECLARATION DE LA PAGE CLIENT (INDISPENSABLE)
// ==========================================
class PageClient extends StatefulWidget {
  final bool ouvrirOngletReservation;

  const PageClient({super.key, this.ouvrirOngletReservation = false});

  @override
  _PageClientState createState() => _PageClientState();
}

class _PageClientState extends State<PageClient> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<DateTime> _dates = [];
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  KeleganceResultatTarif? _tarifVerrouille;
  bool _itineraireValide = false;
  bool _calculTarifEnCours = false;
  KeleganceModePaiement _modePaiement = KeleganceModePaiement.carteBancaire;

  final TextEditingController _departController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _reserverRetour = false;
  bool _modifierAdresseRetour = false;
  DateTime? _dateRetour;
  TimeOfDay _timeRetour = const TimeOfDay(hour: 12, minute: 0);
  final TextEditingController _adresseRetourController = TextEditingController();

  final CollectionReference _missionsRef = FirebaseFirestore.instance.collection('missions');
  bool _hideRevenue = false;
  bool _aAccesConsoleChauffeur = false;
  int _calculTarifGeneration = 0;
  bool _intentReservationTraite = false;

  double get _price => _tarifVerrouille?.prix ?? 0.0;
  double get _prixRetourAvecRemise => KeleganceTarif.appliquerRemiseRetour(_price);
  double get _prixEstimeTotal =>
      _reserverRetour ? KeleganceTarif.calculerTotalAllerRetour(_price) : _price;
  bool get _estForfaitAeroGare => _tarifVerrouille?.libelle == KeleganceConfig.libelleForfaitAeroGare;
  int get _nombreTrajetsEstimes => _reserverRetour ? 2 : 1;

  /// v3.4.5 — Retour automatique : départ retour = arrivée aller.
  String get _departRetourEffectif => _destinationController.text.trim();

  /// v3.4.5 — Retour automatique : arrivée retour = départ aller (sauf adresse personnalisée).
  String get _destinationRetourEffectif =>
      _modifierAdresseRetour ? _adresseRetourController.text.trim() : _departController.text.trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _departController.text = "Paris";
    _destinationController.text = "";

    _departController.addListener(_invaliderItineraire);
    _destinationController.addListener(_invaliderItineraire);
    _verifierProfilChauffeur();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.ouvrirOngletReservation || _intentReservationTraite) return;
    _intentReservationTraite = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
      await KeleganceDeepLink.consommerIntentReservation();
    });
  }

  Future<void> _verifierProfilChauffeur() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await KeleganceRoles.initialiserPourUtilisateurCourant();
      final chauffeurDoc = await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get();
      final usersDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final roleUsers = usersDoc.data()?['role']?.toString().toLowerCase();
      final aProfilChauffeur = chauffeurDoc.exists ||
          roleUsers == 'chauffeur' ||
          roleUsers == 'driver' ||
          usersDoc.data()?['accesChauffeur'] == true;
      if (!mounted) return;
      setState(() => _aAccesConsoleChauffeur = aProfilChauffeur);
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance vérif. profil chauffeur: $e');
    }
  }

  Widget _buildBadgeCapaciteVehicule() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: KeleganceConfig.minuitBleuClair.withOpacity(0.72),
        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
        border: Border.all(color: KeleganceConfig.or.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.airline_seat_recline_extra, color: KeleganceConfig.or.withOpacity(0.88), size: 16),
          const SizedBox(width: 8),
          Text(
            KeleganceConfig.libelleCapacitePassagers,
            style: TextStyle(
              color: KeleganceConfig.blancCasse.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlerteTarifClient() {
    if (_calculTarifEnCours) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Calcul du tarif définitif en cours...',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w300),
              ),
            ),
          ],
        ),
      );
    }

    if (!_itineraireValide || _tarifVerrouille == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'Validez l\'itinéraire pour afficher le tarif définitif.',
          style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w300),
        ),
      );
    }

    final tarif = _tarifVerrouille!;

    if (_estForfaitAeroGare) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_outlined, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    KeleganceConfig.libelleForfaitAeroGare,
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${tarif.prix.toStringAsFixed(2)} €',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tarif.libelle,
            style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '${tarif.prix.toStringAsFixed(2)} €',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _revenirConsoleChauffeur() async {
    await AuthService.sauvegarderRoleSession('chauffeur');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KeleganceAuthGate()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _departController.removeListener(_invaliderItineraire);
    _destinationController.removeListener(_invaliderItineraire);
    _departController.dispose();
    _destinationController.dispose();
    _adresseRetourController.dispose();
    super.dispose();
  }

  void _invaliderItineraire() {
    if (!_itineraireValide && _tarifVerrouille == null && !_calculTarifEnCours) return;
    setState(() {
      _itineraireValide = false;
      _tarifVerrouille = null;
      _calculTarifEnCours = false;
    });
  }

  void _invaliderItineraireClient() {
    if (!_itineraireValide && _tarifVerrouille == null) return;
    setState(() {
      _itineraireValide = false;
      _tarifVerrouille = null;
    });
  }

  Future<void> _validerItineraireEtCalculerPrix() async {
    final depart = _departController.text.trim();
    final arrivee = _destinationController.text.trim();

    if (depart.isEmpty || arrivee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Veuillez renseigner le lieu de prise en charge et la destination avant de valider l\'itinéraire.'),
        ),
      );
      return;
    }

    final generation = ++_calculTarifGeneration;
    setState(() {
      _calculTarifEnCours = true;
      _itineraireValide = false;
      _tarifVerrouille = null;
    });

    final result = await KeleganceTarif.estimerPrixComplet(depart, arrivee);
    if (!mounted || generation != _calculTarifGeneration) return;

    setState(() {
      _calculTarifEnCours = false;
      if (result != null) {
        _itineraireValide = true;
        _tarifVerrouille = result;
      }
    });
  }

  Future<void> _showSelecteurMultiDates() async {
    final selection = _dates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        DateTime jourAffiche = selection.isNotEmpty ? selection.first : DateTime.now();
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            bool estSelectionnee(DateTime d) => selection.any(
                  (s) => s.year == d.year && s.month == d.month && s.day == d.day,
                );

            void basculerDate(DateTime d) {
              final normalisee = DateTime(d.year, d.month, d.day);
              setModalState(() {
                if (estSelectionnee(normalisee)) {
                  selection.removeWhere(
                    (s) => s.year == normalisee.year && s.month == normalisee.month && s.day == normalisee.day,
                  );
                } else {
                  selection.add(normalisee);
                  selection.sort((a, b) => a.compareTo(b));
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SÉLECTION MULTI-DATES',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Appuyez sur chaque date pour l\'ajouter ou la retirer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  KeleganceCalendrierMultiDates(
                    selection: selection,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2027),
                    initialMonth: jourAffiche,
                    onToggle: basculerDate,
                  ),
                  if (selection.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selection.map((d) {
                        return InputChip(
                          label: Text('${d.day}/${d.month}/${d.year}'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setModalState(() => selection.remove(d)),
                          backgroundColor: Colors.amber.withOpacity(0.85),
                          labelStyle: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: selection.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _dates
                                ..clear()
                                ..addAll(selection..sort((a, b) => a.compareTo(b)));
                            });
                            Navigator.pop(ctx);
                          },
                    child: Text(
                      selection.isEmpty
                          ? 'Sélectionnez au moins une date'
                          : 'Bloquer ${selection.length} date(s)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KeleganceConfig.minuitBleuClair,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BESOIN D'AIDE ?", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _helpTile(Icons.luggage, "Objet perdu", "Signaler un objet oublié"),
            _helpTile(Icons.gavel, "Litige ou Réclamation", "Problème avec une course"),
            _helpTile(Icons.support_agent, "Support Technique", "Problème avec l'app"),
            _helpTile(Icons.phone_forwarded, "Urgence", "Contacter mon chauffeur"),
          ],
        ),
      ),
    );
  }

  Widget _helpTile(IconData icon, String title, String subtitle) => ListTile(
        leading: Icon(icon, color: Colors.amber),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        onTap: () => Navigator.pop(context),
      );

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: KeleganceConfig.minuitBleu,
      appBar: AppBar(
        title: const Text("ESPACE CLIENT"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: KeleganceRoles.notifierBrasDroit,
            builder: (context, _, __) {
              if (!_aAccesConsoleChauffeur) {
                return const SizedBox.shrink();
              }
              return TextButton.icon(
                onPressed: _revenirConsoleChauffeur,
                icon: const Icon(Icons.local_taxi_outlined, color: Colors.amber, size: 16),
                label: const Text(
                  'Console Chauffeur',
                  style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                ),
              );
            },
          ),
          IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amber),
              onPressed: () => _showHelpModal(context)
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.add_location_alt), text: "Réserver"),
            Tab(icon: Icon(Icons.event_note), text: "Agenda"),
            Tab(icon: Icon(Icons.receipt_long), text: "Factures"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'KELEGANCE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Spécialiste Transferts Gares & Aéroports',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: KeleganceConfig.or.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      _buildBadgeCapaciteVehicule(),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _buildBandeauMiroirClientReservation(),
                _lbl("LIEU DE PRISE EN CHARGE"),
                KeleganceAdresseAutocomplete(
                  controller: _departController,
                  hintText: "Ex: Chatou, 75017, Versailles...",
                  onEdited: _invaliderItineraireClient,
                ),
                const SizedBox(height: 20),

                _lbl("DESTINATION"),
                KeleganceAdresseAutocomplete(
                  controller: _destinationController,
                  hintText: "Aéroport, gare, ou adresse...",
                  onEdited: _invaliderItineraireClient,
                ),
                const SizedBox(height: 20),

                _btn(
                  _itineraireValide ? 'ITINÉRAIRE VALIDÉ ✓' : 'VALIDER L\'ITINÉRAIRE',
                  _itineraireValide ? Colors.green.withOpacity(0.85) : Colors.white12,
                  _itineraireValide ? Colors.white : Colors.amber,
                  _calculTarifEnCours ? () {} : _validerItineraireEtCalculerPrix,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(child: ActionChip(label: Text("Heure : ${_time.format(context)}"), onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _time); if (t != null) setState(() => _time = t);
                    })),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionChip(
                        label: Text(
                          _dates.isNotEmpty
                              ? "${_dates.length} date(s)"
                              : "Sélectionner des dates",
                        ),
                        avatar: Icon(
                          _dates.isNotEmpty ? Icons.check_circle : Icons.calendar_today,
                          size: 14,
                          color: _dates.isNotEmpty ? Colors.green : null,
                        ),
                        onPressed: _showSelecteurMultiDates,
                      ),
                    ),
                  ],
                ),
                if (_dates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dates.map((d) {
                      return Chip(
                        label: Text('${d.day}/${d.month}/${d.year}', style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.amber.withOpacity(0.85),
                        labelStyle: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      "Réserver également le trajet retour", 
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(
                      _modifierAdresseRetour
                          ? "Retour depuis la destination avec adresse personnalisée"
                          : "Prise en charge retour = destination aller · Destination retour = lieu de prise en charge aller",
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    value: _reserverRetour,
                    activeColor: Colors.amber,
                    onChanged: (bool value) {
                      setState(() {
                        _reserverRetour = value;
                        if (!value) {
                          _modifierAdresseRetour = false;
                          _adresseRetourController.clear();
                        }
                      });
                    },
                  ),
                ),

                if (_reserverRetour) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text(
                      "Modifier l'adresse de retour",
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                    ),
                    subtitle: Text(
                      _modifierAdresseRetour
                          ? "Saisissez une destination de retour différente de l'aller"
                          : "Adresses inversées automatiquement — aucune saisie requise",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: _modifierAdresseRetour,
                    activeColor: Colors.amber,
                    onChanged: (value) {
                      setState(() {
                        _modifierAdresseRetour = value;
                        if (!value) _adresseRetourController.clear();
                      });
                    },
                  ),
                  if (_modifierAdresseRetour) ...[
                    const SizedBox(height: 6),
                    KeleganceAdresseAutocomplete(
                      controller: _adresseRetourController,
                      hintText: "Destination de retour",
                      decoration: InputDecoration(
                        hintText: "Destination de retour",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.amber.withOpacity(0.25)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.amber, width: 0.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                  if (!_modifierAdresseRetour &&
                      _departController.text.trim().isNotEmpty &&
                      _destinationController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.22)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRAJET RETOUR (AUTOMATIQUE)',
                            style: TextStyle(color: Colors.amber, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_departRetourEffectif ➔ $_destinationRetourEffectif',
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ActionChip(
                          label: Text("Heure Retour : ${_timeRetour.format(context)}"), 
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: _timeRetour); 
                            if (t != null) setState(() => _timeRetour = t);
                          }
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ActionChip(
                          label: Text(
                            _dateRetour != null 
                                ? "${_dateRetour!.day}/${_dateRetour!.month}/${_dateRetour!.year}" 
                                : "Date du Retour"
                          ), 
                          avatar: Icon(
                            _dateRetour != null ? Icons.check_circle : Icons.calendar_today, 
                            size: 14, 
                            color: _dateRetour != null ? Colors.green : null
                          ), 
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context, 
                              initialDate: _dates.isNotEmpty ? _dates.first : DateTime.now(), 
                              firstDate: DateTime.now(), 
                              lastDate: DateTime(2027)
                            );
                            if (d != null) {
                              setState(() => _dateRetour = d);
                            }
                          }
                        )
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                _lbl('TARIF DÉFINITIF'),
                const SizedBox(height: 8),
                _buildAlerteTarifClient(),

                if (_itineraireValide && _price > 0) ...[
                  const SizedBox(height: 16),
                  _recap(_prixEstimeTotal, _nombreTrajetsEstimes),
                  if (_reserverRetour)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Aller-retour — Aller ${_price.toStringAsFixed(2)} € + Retour ${_prixRetourAvecRemise.toStringAsFixed(2)} € (−10 %) = ${_prixEstimeTotal.toStringAsFixed(2)} €',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w300),
                      ),
                    ),
                ],

                if (_itineraireValide &&
                    _departController.text.isNotEmpty &&
                    _destinationController.text.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSelectionPaiementClient(),
                  const SizedBox(height: 15),
                  _btn("VALIDER LA RÉSERVATION", Colors.amber, Colors.black, () async {
                    final user = FirebaseAuth.instance.currentUser;

                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.red, content: Text("Erreur : Aucun utilisateur connecté")),
                      );
                      return;
                    }

                    if (!_itineraireValide || _tarifVerrouille == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.orange,
                          content: Text("Veuillez valider l'itinéraire pour figer le tarif avant de réserver."),
                        ),
                      );
                      return;
                    }

                    if (_dates.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.orange,
                          content: Text("Veuillez sélectionner au moins une date pour votre réservation."),
                        ),
                      );
                      return;
                    }

                    if (_reserverRetour && _dateRetour == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.orange, content: Text("Veuillez sélectionner une date pour votre trajet retour")),
                      );
                      return;
                    }

                    if (_reserverRetour && _modifierAdresseRetour && _adresseRetourController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.orange, content: Text("Veuillez saisir l'adresse de retour")),
                      );
                      return;
                    }

                    final montantTotal = _prixEstimeTotal;
                    final prixUnitaire = _tarifVerrouille!.prix;
                    final prixRetourRemise = KeleganceTarif.appliquerRemiseRetour(prixUnitaire);
                    final stripeSelectionne = _modePaiement == KeleganceModePaiement.stripe;
                    if (stripeSelectionne) {
                      final ok = await KeleganceStripePaiement.ouvrirFormulaireTest(
                        context,
                        montant: montantTotal,
                      );
                      if (!ok) return;
                    }

                    final champsPaiement = <String, dynamic>{
                      'modePaiement': _modePaiement.id,
                      if (stripeSelectionne) ...KeleganceStripePaiement.champsFirestoreStripe(),
                    };

                    try {
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                      final phoneClient = userDoc.data()?['phone']?.toString().trim() ?? '';

                      for (final dateCourse in _dates) {
                        await FirebaseFirestore.instance.collection('missions').add({
                          'client': user.email,
                          if (phoneClient.isNotEmpty) 'phone': phoneClient,
                          'depart': _departController.text,
                          'destination': _destinationController.text,
                          'statut': 'EN ATTENTE',
                          'heure': _time.format(context),
                          'date': KeleganceMissionTri.formaterDateFirestore(dateCourse),
                          'prix': prixUnitaire,
                          'libelleTarif': _tarifVerrouille!.libelle,
                          'createdAt': FieldValue.serverTimestamp(),
                          ...champsPaiement,
                        });
                      }

                      if (_reserverRetour && _dateRetour != null) {
                        await FirebaseFirestore.instance.collection('missions').add({
                          'client': user.email,
                          if (phoneClient.isNotEmpty) 'phone': phoneClient,
                          'depart': _departRetourEffectif,
                          'destination': _destinationRetourEffectif,
                          'statut': 'EN ATTENTE',
                          'heure': _timeRetour.format(context),
                          'date': KeleganceMissionTri.formaterDateFirestore(_dateRetour!),
                          'prix': prixRetourRemise,
                          'prixBrutRetour': prixUnitaire,
                          'remiseRetour': KeleganceTarif.tauxRemiseRetourAllerRetour,
                          'libelleTarif': _tarifVerrouille!.libelle,
                          'createdAt': FieldValue.serverTimestamp(),
                          'type': 'BON DE COMMANDE RETOUR',
                          ...champsPaiement,
                        });
                      }

                      if (!mounted) return;
                      final nbDates = _dates.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          content: Text(
                            stripeSelectionne
                                ? (_reserverRetour
                                    ? 'Carte enregistrée — $nbDates aller(s) & retour confirmés !'
                                    : 'Carte enregistrée — $nbDates réservation(s) confirmée(s) !')
                                : (_reserverRetour
                                    ? 'Réservation aller ($nbDates date(s)) & retour validés !'
                                    : '$nbDates réservation(s) enregistrée(s) avec tarif figé !'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );

                      setState(() {
                        _departController.clear();
                        _destinationController.clear();
                        _itineraireValide = false;
                        _tarifVerrouille = null;
                        _reserverRetour = false;
                        _modifierAdresseRetour = false;
                        _adresseRetourController.clear();
                        _dateRetour = null;
                        _dates.clear();
                        _modePaiement = KeleganceModePaiement.carteBancaire;
                      });
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red, content: Text("Erreur : $error")),
                      );
                    }
                  }),
                ],
                const SizedBox(height: 20),
                _buildPremiumCharter(), 
                _buildServiceIcons(),
              ],
            ),
          ),
          
          FirebaseAuth.instance.currentUser?.email == 'admin@kelegance-prestige.com'
              ? _buildChauffeurAgendaView()
              : _buildAgendaView(),
          _buildFacturesView(),
        ],
      ),
    );
  }
  
  // (La suite des widgets d'affichage type _buildPremiumCharter, etc., vient juste après...)
  // =========================================================================
  // 1. VUE AGENDA STANDARD CLIENT — v6.4.0 (effet miroir + communication)
  // =========================================================================
  bool _statutCommunicationClientActive(String statut) {
    final s = statut.toUpperCase().replaceAll('É', 'E').trim();
    return s == 'EN_ROUTE' || s == 'EN ROUTE' || s == 'SUR PLACE';
  }

  ({String libelle, Color couleur, IconData icone}) _miroirStatutClient(String statut, String? messageClient) {
    final s = statut.toUpperCase().replaceAll('É', 'E').trim();
    if (s == 'EN_ROUTE' || s == 'EN ROUTE') {
      return (
        libelle: KeleganceCommunication.messageClientEnRoute,
        couleur: const Color(0xFF42A5F5),
        icone: Icons.directions_car_filled_outlined,
      );
    }
    if (s == 'SUR PLACE') {
      return (
        libelle: KeleganceCommunication.messageClientSurPlace,
        couleur: Colors.orange,
        icone: Icons.place_outlined,
      );
    }
    if (s == 'EN COURSE') {
      return (
        libelle: messageClient ?? 'Course en cours vers votre destination',
        couleur: Colors.green,
        icone: Icons.navigation_outlined,
      );
    }
    if (s == 'PLANIFIÉ' || s == 'PLANIFIE' || s == 'REDISPATCHÉ' || s == 'REDISPATCHE') {
      return (libelle: 'Réservation confirmée', couleur: Colors.green, icone: Icons.verified_outlined);
    }
    if (s == 'TERMINÉ' || s == 'TERMINE') {
      return (libelle: 'Course terminée', couleur: Colors.grey, icone: Icons.check_circle_outline);
    }
    if (s.contains('ANNUL')) {
      return (libelle: 'Course annulée', couleur: Colors.redAccent, icone: Icons.cancel_outlined);
    }
    return (libelle: 'En attente de confirmation', couleur: Colors.amber, icone: Icons.hourglass_top_outlined);
  }

  String? _extraireTelChauffeur(Map<String, dynamic> data) {
    for (final cle in ['chauffeurTel', 'chauffeurPhone', 'telChauffeur']) {
      final v = data[cle]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Widget _buildBoutonsCommunicationClient(String? tel) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.withOpacity(0.65), width: 0.8),
                foregroundColor: const Color(0xFF81C784),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium)),
              ),
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: const Text('WhatsApp Pro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              onPressed: tel == null || tel.isEmpty
                  ? null
                  : () => unawaited(KeleganceCommunication.ouvrirWhatsApp(context, tel)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: KeleganceConfig.or.withOpacity(0.55), width: 0.8),
                foregroundColor: KeleganceConfig.or,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium)),
              ),
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Appel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              onPressed: tel == null || tel.isEmpty
                  ? null
                  : () => unawaited(KeleganceCommunication.ouvrirAppel(context, tel)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarteAgendaClientMiroir(Map<String, dynamic> data) {
    final dateText = data['date'] ?? 'Date inconnue';
    final heureText = data['heure'] ?? '';
    final depart = data['depart'] ?? 'Non spécifié';
    final destination = data['destination'] ?? 'Non spécifiée';
    final statutReel = data['statut'] ?? 'EN ATTENTE';
    final messageClient = data['notificationClient']?.toString();
    final miroir = _miroirStatutClient(statutReel, messageClient);
    final chauffeurNom = data['chauffeurNom']?.toString() ?? 'Nicolas';
    final chauffeurVehicule = data['chauffeurVehicule']?.toString() ?? 'Véhicule Premium Kelegance';
    final telChauffeur = _extraireTelChauffeur(data);
    final communicationActive = _statutCommunicationClientActive(statutReel);
    final enSuiviLive = communicationActive || statutReel.toUpperCase().contains('EN COURSE');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enSuiviLive ? miroir.couleur.withOpacity(0.55) : Colors.white12,
          width: enSuiviLive ? 1.0 : 0.6,
        ),
        boxShadow: enSuiviLive
            ? [BoxShadow(color: miroir.couleur.withOpacity(0.12), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (enSuiviLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [miroir.couleur.withOpacity(0.22), miroir.couleur.withOpacity(0.06)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Icon(miroir.icone, color: miroir.couleur, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          miroir.libelle.toUpperCase(),
                          style: TextStyle(
                            color: miroir.couleur,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            height: 1.3,
                          ),
                        ),
                        if (communicationActive) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$chauffeurNom · $chauffeurVehicule',
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (communicationActive)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: miroir.couleur, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateText · $heureText',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text('$depart ➔ $destination', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                if (communicationActive) ...[
                  const SizedBox(height: 14),
                  _buildBoutonsCommunicationClient(telChauffeur),
                  if (telChauffeur == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Numéro chauffeur bientôt disponible',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandeauMiroirClientReservation() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return KeleganceLivePulseHeader(
      child: KeleganceMissionsStreamBuilder(
        afficherIndicateurLive: false,
        filtre: (docs) => docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['client'] == user.email)
            .toList(),
        builder: (context, snapshot, _) {
          if (snapshot == null) return const SizedBox.shrink();
          final actives = snapshot.docs.where((doc) {
            final statut = (doc.data() as Map<String, dynamic>)['statut']?.toString() ?? '';
            return _statutCommunicationClientActive(statut);
          }).toList();
          if (actives.isEmpty) return const SizedBox.shrink();

          final data = actives.first.data() as Map<String, dynamic>;
          final miroir = _miroirStatutClient(data['statut']?.toString() ?? '', data['notificationClient']?.toString());
          final tel = _extraireTelChauffeur(data);

          return Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [miroir.couleur.withOpacity(0.18), const Color(0xFF0D0D0D)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: miroir.couleur.withOpacity(0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(miroir.icone, color: miroir.couleur, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        miroir.libelle,
                        style: TextStyle(color: miroir.couleur, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBoutonsCommunicationClient(tel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgendaView() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(
        child: Text("Veuillez vous connecter pour voir votre agenda.", style: TextStyle(color: Colors.white)),
      );
    }

    return KeleganceMissionsStreamBuilder(
      filtre: (docs) => docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['client'] == user.email)
          .toList(),
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = KeleganceMissionTri.trierChronologique(snapshot.docs);

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _lbl("MES PROCHAINES COURSES"),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Aucune course planifiée pour le moment.",
                  style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _lbl("MES PROCHAINES COURSES"),
            if (live)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Synchronisation…',
                  style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final statutReel = data['statut'] ?? 'EN ATTENTE';
              if (_statutCommunicationClientActive(statutReel) ||
                  statutReel.toUpperCase().contains('EN COURSE') ||
                  statutReel == 'PLANIFIÉ' ||
                  statutReel == 'REDISPATCHÉ') {
                return _buildCarteAgendaClientMiroir(data);
              }

              String dateText = data['date'] ?? 'Date inconnue';
              String heureText = data['heure'] ?? '';
              String depart = data['depart'] ?? 'Non spécifié';
              String destination = data['destination'] ?? 'Non spécifiée';
              final miroir = _miroirStatutClient(statutReel, data['notificationClient']?.toString());

              return _appointmentCard(
                "$dateText - $heureText",
                "$depart ➔ $destination",
                miroir.libelle,
                miroir.couleur,
              );
            }),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 2. VUE SPÉCIFIQUE CHAUFFEUR / ADMIN
  // =========================================================================
  Widget _buildChauffeurAgendaView() {
    return KeleganceMissionsStreamBuilder(
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = KeleganceMissionTri.trierChronologique(snapshot.docs);

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _lbl("TABLEAU DE BORD CHAUFFEUR"),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Aucune demande de course pour le moment.",
                  style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _lbl("TOUTES LES DEMANDES CLIENTS"),
            if (live)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Mise à jour en direct…',
                  style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              
              String dateText = data['date'] ?? 'Date inconnue';
              String heureText = data['heure'] ?? '';
              String statut = data['statut'] ?? 'EN ATTENTE';
              String clientEmail = data['client'] ?? 'Client inconnu';
              String typeMission = data['type'] ?? 'ALLER';
              final itineraire = KeleganceGestionReservations.formaterItineraire(data);

              Color statutColor = Colors.amber;
              if (statut == 'PLANIFIÉ' || statut == 'TERMINÉ') {
                statutColor = Colors.green;
              } else if (statut == 'EN COURSE' || statut == 'SUR PLACE') {
                statutColor = Colors.blue;
              } else if (statut == 'ANNULÉ') {
                statutColor = Colors.redAccent;
              }

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (typeMission == 'BON DE COMMANDE RETOUR') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_return, color: Colors.amber, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "BON DE COMMANDE RETOUR",
                                style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "$dateText - $heureText", 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                          ),
                          Chip(
                            label: Text(
                              statut, 
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                            backgroundColor: statutColor,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(itineraire, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      if (data['note']?.toString().trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note : ${data['note']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text("Client : $clientEmail", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500)),
                      const Divider(color: Colors.white24, height: 25),
                      KeleganceGestionReservations.barreActions(
                        context: context,
                        docId: docId,
                        data: data,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _showReglementaireModal(context, data);
                            },
                            icon: const Icon(Icons.gavel, color: Colors.amber, size: 16),
                            label: const Text("Voir le Bon", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

// =========================================================================
  // 3. VUE HISTORIQUE DES FACTURES CLIENT
  // =========================================================================
  Widget _buildFacturesView() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text("Veuillez vous connecter pour voir vos documents.", style: TextStyle(color: Colors.white)),
      );
    }

    return KeleganceFacturesStreamBuilder(
      filtre: (docs) {
        final mail = user.email?.trim().toLowerCase();
        return docs
            .where((doc) => KeleganceFacturesService.peutVoirFacture(
                  doc.data() as Map<String, dynamic>,
                  email: mail,
                ))
            .toList();
      },
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = KeleganceFacturesService.trierParDateRecente(snapshot.docs);
        final enAttente = docs.where((d) {
          final s = KeleganceFacturesService.presenterStatut(
            (d.data() as Map<String, dynamic>)['statut']?.toString(),
          );
          return s.libelle == 'En attente';
        }).length;
        final payees = docs.where((d) {
          final s = KeleganceFacturesService.presenterStatut(
            (d.data() as Map<String, dynamic>)['statut']?.toString(),
          );
          return s.libelle == 'Payée';
        }).length;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _lbl("MES DOCUMENTS"),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Aucune facture disponible pour le moment.",
                  style: TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const KeleganceListeBonsCommandeRetour(
                titre: 'MES BONS DE COMMANDE RETOUR',
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _lbl("MES DOCUMENTS"),
            if (live)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Données financières synchronisées',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, letterSpacing: 0.4),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPastilleStatutFacture('En attente', enAttente, Colors.orangeAccent),
                const SizedBox(width: 8),
                _buildPastilleStatutFacture('Payées', payees, Colors.greenAccent),
                const SizedBox(width: 8),
                _buildPastilleStatutFacture('Total', docs.length, Colors.amber),
              ],
            ),
            const SizedBox(height: 14),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final numero = data['numero'] ?? 'Facture #0000';
              final dateText = data['date'] ?? 'Date inconnue';
              final montant = data['montant'] ?? '0.00€';
              final statut = KeleganceFacturesService.presenterStatut(data['statut']?.toString());

              return _factureTile(
                numero,
                dateText,
                montant,
                statutLibelle: statut.libelle,
                statutCouleur: statut.couleur,
                lienWeb: data['lienWeb']?.toString(),
                miseAJourLive: live,
              );
            }),
            const SizedBox(height: 28),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const KeleganceListeBonsCommandeRetour(
              titre: 'MES BONS DE COMMANDE RETOUR',
            ),
          ],
        );
      },
    );
  }

  Widget _buildPastilleStatutFacture(String label, int count, Color couleur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: couleur.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: couleur.withOpacity(0.9), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. MODALS & DIALOGS (RÉGLEMENTAIRE & REDISPATCH)
  // =========================================================================
  void _showReglementaireModal(BuildContext context, Map<String, dynamic> data) {
    String dateText = data['date'] ?? 'Date inconnue';
    String heureText = data['heure'] ?? '';
    String depart = data['depart'] ?? 'Non spécifié';
    String destination = data['destination'] ?? 'Non spécifiée';
    String clientEmail = data['client'] ?? 'Client inconnu';
    String typeMission = data['type'] ?? 'ALLER SIMPLE';
    String prixText = data['prix'] != null ? "${data['prix']} €" : "Tarif forfaitaire";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.amber, width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.gavel, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  typeMission == 'BON DE COMMANDE RETOUR' 
                      ? "BON DE COMMANDE RETOUR" 
                      : "BON DE COMMANDE VTC",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DOCUMENT DE CONFORMITÉ RÉGLEMENTAIRE\n(Article L. 3122-9 du Code des transports)",
                  style: TextStyle(color: Colors.white60, fontSize: 10, fontStyle: FontStyle.italic),
                ),
                const Divider(color: Colors.amber, height: 20),
                
                _buildModalRow("Exploitant :", "KELEGANCE PRESTIGE"),
                _buildModalRow("Client :", clientEmail),
                _buildModalRow("Date de prise en charge :", dateText),
                _buildModalRow("Heure de récupération :", heureText),
                _buildModalRow("Lieu de prise en charge :", depart),
                _buildModalRow("Destination :", destination),
                _buildModalRow("Prestation :", "Transport Public Particulier de Personnes"),
                _buildModalRow("Tarif :", prixText),
                
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Ce document atteste d'une réservation préalable effectuée par le client.",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 5. COMPOSANTS GRAPHIQUES (TILES & CARDS)
  // =========================================================================
  Widget _appointmentCard(String date, String lieu, String statut, Color color) => Card(
        margin: const EdgeInsets.only(bottom: 15),
        color: Colors.white10,
        child: ListTile(
          leading: const Icon(Icons.calendar_today, color: Colors.amber),
          title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(lieu, style: const TextStyle(color: Colors.white70)),
          trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text(statut, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
      );

  Widget _factureTile(
    String ref,
    String date,
    String prix, {
    String? lienWeb,
    String? statutLibelle,
    Color? statutCouleur,
    bool miseAJourLive = false,
  }) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: miseAJourLive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              )
            : null,
        child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white10,
        child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFFD4AF37)),
            title: Text(ref, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lienWeb != null && lienWeb.isNotEmpty ? '$date · Consulter en ligne' : date,
                  style: const TextStyle(color: Colors.white60),
                ),
                if (statutLibelle != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (statutCouleur ?? Colors.white54).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statutLibelle,
                      style: TextStyle(
                        color: statutCouleur ?? Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: lienWeb != null && lienWeb.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(prix, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      IconButton(
                        tooltip: 'Partager',
                        icon: const Icon(Icons.ios_share_rounded, color: Colors.amber, size: 20),
                        onPressed: () => unawaited(
                          KeleganceDocumentsClient.partagerLien(
                            context,
                            KeleganceDocumentPartage(
                              token: '',
                              lienWeb: lienWeb,
                              type: 'FACTURE TTC',
                              titre: ref,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Envoyer par e-mail',
                        icon: const Icon(Icons.email_outlined, color: Colors.amber, size: 20),
                        onPressed: () => unawaited(
                          KeleganceDocumentsClient.envoyerLienParEmail(
                            context,
                            KeleganceDocumentPartage(
                              token: '',
                              lienWeb: lienWeb,
                              type: 'FACTURE TTC',
                              titre: ref,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(prix, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            onTap: lienWeb != null && lienWeb.isNotEmpty
                ? () => unawaited(launchUrl(Uri.parse(lienWeb), mode: LaunchMode.externalApplication))
                : null),
      ),
      );

  Widget _buildServiceIcons() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl("VOTRE CONFORT À BORD"),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Svc(Icons.local_drink, "BOUTEILLE D'EAU", isRule: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _Svc(Icons.cable, "CÂBLE DE RECHARGE TYPE C", isRule: false)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconeRegleConfort(Icons.smoke_free),
                    const SizedBox(width: 28),
                    _iconeRegleConfort(Icons.no_food),
                    const SizedBox(width: 28),
                    _iconeRegleConfort(Icons.pets),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  /// Icônes épurées des règles à bord — style conciergerie (v3.2.0).
  Widget _iconeRegleConfort(IconData icone) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.withOpacity(0.35), width: 0.8),
        color: Colors.red.withOpacity(0.06),
      ),
      child: Icon(icone, color: Colors.red, size: 22),
    );
  }

  // =========================================================================
  // CHARTE QUALITÉ ET ENGAGEMENT PREMIUM
  // =========================================================================
  Widget _buildPremiumCharter() => Container(
        margin: const EdgeInsets.only(top: 15, bottom: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.03),
          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  "L'EXCELLENCE KELEGANCE",
                  style: TextStyle(
                    color: Colors.amber[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _charterItem(Icons.star, "Service Irréprochable & Ponctualité", "Un chauffeur professionnel, en tenue soignée, rigoureusement à l'heure."),
            const SizedBox(height: 10),
            _charterItem(Icons.clean_hands, "Hygiène & Confort Absolu", "Véhicule de prestige d'une propreté clinique, garanti sans odeur."),
            const SizedBox(height: 10),
            _charterItem(Icons.sentiment_very_satisfied, "Sérieux & Convivialité", "Le sens du détail, l'accueil chaleureux et la discrétion d'un service privé."),
          ],
        ),
      );

  Widget _charterItem(IconData icon, String title, String subtitle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber.withOpacity(0.7), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      );

  // L'infrastructure automatique se déclenche ici au passage à "TERMINÉ"
  void _avancerStatutMission(String id, String statutActuel, Map<String, dynamic> missionData) {
    String nouveauStatut = "PLANIFIÉ";

    if (statutActuel == "PLANIFIÉ") {
      nouveauStatut = "SUR PLACE";
    } else if (statutActuel == "SUR PLACE") {
      nouveauStatut = "EN COURSE";
    } else if (statutActuel == "EN COURSE") {
      nouveauStatut = "TERMINÉ";
      // Facture électronique + e-mail : Cloud Function onMissionTerminee (statut TERMINÉ)
    } else {
      nouveauStatut = "PLANIFIÉ";
    }

    _missionsRef.doc(id).update({
      'statut': nouveauStatut,
    });
  }

  void _showReservationsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "MES RÉSERVATIONS PLANIFIÉES",
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: KeleganceMissionsStreamBuilder(
                builder: (context, snapshot, live) {
                  if (snapshot == null) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  final docs = KeleganceMissionTri.trierChronologique(snapshot.docs);

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Aucune mission planifiée",
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;

                      final heure = data['heure'] ?? '';
                      final client = data['client'] ?? '';
                      final itineraire = KeleganceGestionReservations.formaterItineraire(data);
                      final statut = data['statut'] ?? 'PLANIFIÉ';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        decoration: live && index == 0
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.12),
                                    blurRadius: 8,
                                  ),
                                ],
                              )
                            : null,
                        child: _resItem(id, heure, client, itineraire, statut, data),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resItem(String id, String heure, String client, String trajet, String statut, Map<String, dynamic> data) {
    Color statutColor = Colors.blue;
    if (statut == "SUR PLACE") statutColor = Colors.orange;
    if (statut == "EN COURSE") statutColor = Colors.green;
    if (statut == "TERMINÉ") statutColor = Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xff1e1e1e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff2a2a2a)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heure,
                        style: const TextStyle(color: Color(0xffbfa054), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        client,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trajet,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _avancerStatutMission(id, statut, data),
                  style: ElevatedButton.styleFrom(backgroundColor: statutColor),
                  child: Text(
                    statut == "PLANIFIÉ" ? "Arrivé" : (statut == "SUR PLACE" ? "Démarrer" : "Terminer"),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KeleganceGestionReservations.barreActions(
              context: context,
              docId: id,
              data: data,
              fontSize: 10,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showReglementaireModal(context, data),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.gavel, color: Colors.amber, size: 14),
                  SizedBox(width: 5),
                  Text(
                    "Voir le Bon (Contrôle VTC)",
                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _missionCard(dynamic m, int idx, {bool isPriority = false}) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 15),
      child: Card(
        color: isPriority ? Colors.amber.withOpacity(0.15) : Colors.white10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: isPriority ? Colors.amber : Colors.transparent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m.heure, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(m.statut, style: TextStyle(color: isPriority ? Colors.amber : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Text(m.client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("${m.depart} ➔ ${m.destination}", style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
              const Divider(color: Colors.white10, height: 10),
              InkWell(
                onTap: () => _showReglementaireModal(context, {
                  'client': m.client,
                  'heure': m.heure,
                  'destination': m.destination,
                }),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.gavel, color: Colors.amber, size: 14),
                    SizedBox(width: 6),
                    Text("VOIR LE BON REGLEMENTAIRE", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawer() {
    return Drawer(
      child: Container(
        color: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xff1a1a1a)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
                  SizedBox(height: 10),
                  Text("KELEGANCE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                  Text("Espace Partenaire", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.amber),
              title: const Text("Tableau de bord"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.amber),
              title: const Text("Mes Missions"),
              onTap: () {
                Navigator.pop(context);
                _showReservationsList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.euro, color: Colors.amber),
              title: const Text("Revenus & Factures"),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xff121212),
                    title: const Text("REVENUS & FACTURES", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                    content: const Text(
                      "Les factures sont générées automatiquement (lien web + e-mail client) à la fin de course. Le bon de commande est envoyé dès la réservation.",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text("OK", style: TextStyle(color: Colors.amber)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.amber),
              title: const Text("Paramètres"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Déconnexion"),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMissionDialog() {
    final TextEditingController clientCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController heureCtrl = TextEditingController();
    final TextEditingController departCtrl = TextEditingController();
    final TextEditingController destCtrl = TextEditingController();
    final TextEditingController dateCtrl = TextEditingController(
      text: "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}"
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff121212),
        title: const Text(
          "NOUVELLE RÉSERVATION",
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nom du Client",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email du Client (pour facture auto)",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              TextField(
                controller: heureCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Heure (ex: 14:30)",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              TextField(
                controller: dateCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Date (JJ/MM/AAAA)",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              KeleganceAdresseAutocomplete(
                controller: departCtrl,
                labelText: "Lieu de prise en charge",
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Lieu de prise en charge",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              KeleganceAdresseAutocomplete(
                controller: destCtrl,
                labelText: "Destination",
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Destination",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANNULER", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (clientCtrl.text.isNotEmpty && heureCtrl.text.isNotEmpty) {
                _missionsRef.add({
                  'client': clientCtrl.text.toUpperCase(),
                  'email': emailCtrl.text.trim(),
                  'heure': heureCtrl.text,
                  'date': dateCtrl.text,
                  'depart': departCtrl.text,
                  'destination': destCtrl.text.toUpperCase(),
                  'statut': 'PLANIFIÉ',
                });
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Réservation ajoutée avec succès !"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("AJOUTER", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  
  // =========================================================================
  // WIDGETS ET COMPOSANTS GRAPHIQUES REQUIS POUR L'ÉCRAN
  // =========================================================================

  Widget _lbl(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _btn(String label, Color bg, Color text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _recap(double total, int trips) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: KeleganceConfig.minuitBleuClair.withOpacity(0.55),
        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
        border: Border.all(color: KeleganceConfig.or.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Estimation ($trips trajet(s)) :", style: TextStyle(color: KeleganceConfig.blancCasse.withOpacity(0.72))),
              Text(
                "${total.toStringAsFixed(2)} €",
                style: const TextStyle(color: KeleganceConfig.or, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            KeleganceConfig.libelleCapacitePassagers,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: KeleganceConfig.or.withOpacity(0.58),
              fontSize: 10,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPaiementClient() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('Mode de paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ...KeleganceModePaiement.values.map((mode) {
            final selected = _modePaiement == mode;
            final IconData icone;
            final String sousTitre;
            switch (mode) {
              case KeleganceModePaiement.stripe:
                icone = Icons.lock_rounded;
                sousTitre = 'Paiement en ligne à l\'avance — carte enregistrée';
                break;
              case KeleganceModePaiement.especes:
                icone = Icons.payments_outlined;
                sousTitre = 'Règlement en liquide auprès du chauffeur';
                break;
              case KeleganceModePaiement.carteBancaire:
                icone = Icons.credit_card_outlined;
                sousTitre = 'Règlement par carte auprès du chauffeur';
                break;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: selected ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                leading: Icon(icone, color: selected ? Colors.amber : Colors.white38),
                title: Text(mode.libelle, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  sousTitre,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Colors.amber : Colors.white24),
                onTap: () => setState(() => _modePaiement = mode),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _Svc(IconData icon, String label, {required bool isRule}) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isRule ? Colors.red.withOpacity(0.06) : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRule ? Colors.red.withOpacity(0.35) : Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isRule ? Colors.red : Colors.greenAccent, size: 20),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isRule ? Colors.red : Colors.green[200], fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModalRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}


/// Overlay système — bulle discrète en course (v3.0.1).
abstract final class KeleganceOverlayCourse {
  static const String portName = 'KeleganceOverlayPort';
  static const SystemWindowPrefMode prefMode = SystemWindowPrefMode.OVERLAY;
  static const int bubbleWidth = 76;
  static const int bubbleHeight = 92;

  /// Permissions overlay système — initialisées au démarrage app (v3.2.2).
  static Future<void> initialiserPermissions() async {
    if (!keleganceEstAndroid) return;
    final ok = await SystemAlertWindow.checkPermissions(prefMode: prefMode);
    if (ok != true) {
      await SystemAlertWindow.requestPermissions(prefMode: prefMode);
    }
  }
}

/// Pont Isolate overlay ↔ app principale (clic bulle → réouverture).
class KeleganceOverlayBridge {
  static ReceivePort? _receivePort;
  static VoidCallback? _onOpenApp;

  static void init(VoidCallback onOpenApp) {
    if (kIsWeb) return;
    _onOpenApp = onOpenApp;
    _receivePort?.close();
    _receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(KeleganceOverlayCourse.portName);
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, KeleganceOverlayCourse.portName);
    _receivePort!.listen((message) {
      if (message == 'open_app') _onOpenApp?.call();
    });
  }

  static void dispose() {
    _receivePort?.close();
    _receivePort = null;
    IsolateNameServer.removePortNameMapping(KeleganceOverlayCourse.portName);
    _onOpenApp = null;
  }

  static void demanderOuvertureApp() {
    final port = IsolateNameServer.lookupPortByName(KeleganceOverlayCourse.portName);
    port?.send('open_app');
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KeleganceOverlayBubble(),
    ),
  );
}

/// Widget affiché dans la fenêtre overlay Android.
class KeleganceOverlayBubble extends StatelessWidget {
  const KeleganceOverlayBubble({super.key});

  static const Color _or = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          KeleganceOverlayBridge.demanderOuvertureApp();
          SystemAlertWindow.closeSystemWindow(prefMode: KeleganceOverlayCourse.prefMode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: _or, width: 1.4),
                boxShadow: [
                  BoxShadow(color: _or.withOpacity(0.25), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/pirogue_gps.png.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('K', style: TextStyle(color: _or, fontWeight: FontWeight.bold, fontSize: 22)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'KELEGANCE',
              style: TextStyle(color: _or, fontSize: 8, fontWeight: FontWeight.w500, letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1. DÉCLARATION INDISPENSABLE DE LA PAGE ---
class PageConsole extends StatefulWidget {
  final bool ouvrirDirectement;
  final bool forceVueChauffeurRestreinte;

  const PageConsole({
    super.key,
    this.ouvrirDirectement = false,
    this.forceVueChauffeurRestreinte = false,
  });

  @override
  State<PageConsole> createState() => _PageConsoleState();
}

/// Réservation instantanée chauffeur — v6.1.0 (tarif figé + trajet retour flexible).
class _PageReservationInstantanee extends StatefulWidget {
  const _PageReservationInstantanee({required this.missionsRef});

  final CollectionReference missionsRef;

  @override
  State<_PageReservationInstantanee> createState() => _PageReservationInstantaneeState();
}

class _PageReservationInstantaneeState extends State<_PageReservationInstantanee> {
  static const Color _or = KeleganceConfig.or;

  final _clientCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _departCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _departRetourCtrl = TextEditingController();
  late final TextEditingController _heureCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _heureRetourCtrl;
  late final TextEditingController _dateRetourCtrl;

  KeleganceResultatTarif? _devisVerrouille;
  bool _itineraireValide = false;
  bool _calculDevisEnCours = false;
  int _calculDevisGeneration = 0;

  bool _planifierRetour = false;
  bool _priseEnChargeRetourPersonnalisee = false;

  String get _departRetourEffectif =>
      _priseEnChargeRetourPersonnalisee ? _departRetourCtrl.text.trim() : _destCtrl.text.trim();

  String get _destinationRetourEffectif => _departCtrl.text.trim();

  double get _prixAller => _devisVerrouille?.prix ?? 0.0;
  double get _prixRetourAvecRemise => KeleganceTarif.appliquerRemiseRetour(_prixAller);
  double get _totalAllerRetour => KeleganceTarif.calculerTotalAllerRetour(_prixAller);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _heureCtrl = TextEditingController(
      text: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    _dateCtrl = TextEditingController(
      text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    _heureRetourCtrl = TextEditingController(text: '12:00');
    _dateRetourCtrl = TextEditingController(
      text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    _departCtrl.addListener(_invaliderItineraire);
    _destCtrl.addListener(_invaliderItineraire);
  }

  @override
  void dispose() {
    _departCtrl.removeListener(_invaliderItineraire);
    _destCtrl.removeListener(_invaliderItineraire);
    _clientCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _departCtrl.dispose();
    _destCtrl.dispose();
    _departRetourCtrl.dispose();
    _heureCtrl.dispose();
    _dateCtrl.dispose();
    _heureRetourCtrl.dispose();
    _dateRetourCtrl.dispose();
    super.dispose();
  }

  void _invaliderItineraire() {
    if (!_itineraireValide && _devisVerrouille == null && !_calculDevisEnCours) return;
    setState(() {
      _itineraireValide = false;
      _devisVerrouille = null;
      _calculDevisEnCours = false;
    });
  }

  void _invaliderItineraireChauffeur() {
    if (!_itineraireValide) return;
    setState(() => _itineraireValide = false);
  }

  Future<void> _validerItineraireEtCalculerDevis() async {
    final depart = _departCtrl.text.trim();
    final arrivee = _destCtrl.text.trim();

    if (depart.isEmpty || arrivee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez le lieu de prise en charge et la destination avant de valider l\'itinéraire.'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
      return;
    }

    final generation = ++_calculDevisGeneration;
    setState(() {
      _calculDevisEnCours = true;
      _itineraireValide = false;
      _devisVerrouille = null;
    });

    final result = await KeleganceTarif.estimerPrixComplet(depart, arrivee);
    if (!mounted || generation != _calculDevisGeneration) return;

    setState(() {
      _calculDevisEnCours = false;
      if (result != null) {
        _itineraireValide = true;
        _devisVerrouille = result;
      }
    });
  }

  InputDecoration _champ(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _or, fontSize: 11, fontWeight: FontWeight.w500),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _or.withOpacity(0.25), width: 0.6)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _or.withOpacity(0.75), width: 0.8)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
    );
  }

  Widget _buildBandeauDevis() {
    if (_calculDevisEnCours) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 18, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _or.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _or.withOpacity(0.35), width: 0.9),
        ),
        child: const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _or)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Calcul du tarif définitif...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (!_itineraireValide || _devisVerrouille == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 18, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'Validez l\'itinéraire pour afficher le tarif définitif.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final devis = _devisVerrouille!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _or.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _or.withOpacity(0.55), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _planifierRetour
                ? 'Total aller-retour : ${_totalAllerRetour.toStringAsFixed(2)} €'
                : 'Tarif définitif : ${devis.prix.toStringAsFixed(2)} €',
            style: const TextStyle(
              color: _or,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          if (_planifierRetour) ...[
            const SizedBox(height: 6),
            Text(
              'Aller ${devis.prix.toStringAsFixed(2)} € + Retour ${_prixRetourAvecRemise.toStringAsFixed(2)} € (−10 %)',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, height: 1.35),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            devis.libelle,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeleganceConfig.noirProfond,
      appBar: AppBar(
        backgroundColor: KeleganceConfig.noirProfond,
        elevation: 0,
        iconTheme: const IconThemeData(color: _or),
        title: const Text(
          'Réservation instantanée',
          style: TextStyle(color: _or, fontWeight: FontWeight.w400, fontSize: 15, letterSpacing: 0.4),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _clientCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Nom du client'),
            ),
            TextField(
              controller: _emailCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('E-mail client'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Téléphone client'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _heureCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Heure aller'),
            ),
            TextField(
              controller: _dateCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Date aller (JJ/MM/AAAA)'),
            ),
            KeleganceAdresseAutocomplete(
              controller: _departCtrl,
              labelText: 'Lieu de prise en charge',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Lieu de prise en charge'),
              onEdited: _invaliderItineraireChauffeur,
              onSelected: (_) => _invaliderItineraireChauffeur(),
            ),
            KeleganceAdresseAutocomplete(
              controller: _destCtrl,
              labelText: 'Destination',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
              decoration: _champ('Destination'),
              onEdited: _invaliderItineraireChauffeur,
              onSelected: (_) => _invaliderItineraireChauffeur(),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _itineraireValide ? Colors.green.withOpacity(0.7) : _or.withOpacity(0.45)),
                foregroundColor: _itineraireValide ? Colors.green : _or,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: _calculDevisEnCours ? null : _validerItineraireEtCalculerDevis,
              child: Text(
                _itineraireValide ? 'Itinéraire validé ✓' : 'Valider l\'itinéraire',
                style: const TextStyle(fontSize: 12, letterSpacing: 0.4),
              ),
            ),
            _buildBandeauDevis(),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Planifier un trajet retour',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _priseEnChargeRetourPersonnalisee
                    ? 'Retour personnalisé : prise en charge différente de la destination aller'
                    : 'Par défaut : le trajet retour s\'effectuera depuis le point d\'arrivée du trajet aller',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              value: _planifierRetour,
              activeColor: _or,
              onChanged: (value) {
                setState(() {
                  _planifierRetour = value;
                  if (!value) {
                    _priseEnChargeRetourPersonnalisee = false;
                    _departRetourCtrl.clear();
                  }
                });
              },
            ),
            if (_planifierRetour) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Prise en charge retour différente',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                subtitle: const Text(
                  'Ex. Aller A→B, retour C→A avec C ≠ B',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                value: _priseEnChargeRetourPersonnalisee,
                activeColor: _or,
                onChanged: (value) {
                  setState(() {
                    _priseEnChargeRetourPersonnalisee = value;
                    if (!value) _departRetourCtrl.clear();
                  });
                },
              ),
              if (_priseEnChargeRetourPersonnalisee)
                KeleganceAdresseAutocomplete(
                  controller: _departRetourCtrl,
                  labelText: 'Prise en charge retour',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _champ('Prise en charge retour (adresse C)'),
                  onSelected: (_) => _invaliderItineraireChauffeur(),
                ),
              if (_departCtrl.text.trim().isNotEmpty && _destCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _or.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _or.withOpacity(0.22)),
                  ),
                  child: Text(
                    'Retour : $_departRetourEffectif ➔ $_destinationRetourEffectif',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
              TextField(
                controller: _heureRetourCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                decoration: _champ('Heure retour'),
              ),
              TextField(
                controller: _dateRetourCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                decoration: _champ('Date retour (JJ/MM/AAAA)'),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _or.withOpacity(0.65), width: 0.7),
                foregroundColor: _or,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                if (_clientCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty) return;
                if (!_itineraireValide || _devisVerrouille == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Validez l\'itinéraire pour figer le tarif avant confirmation.'),
                      backgroundColor: Color(0xFFD4AF37),
                    ),
                  );
                  return;
                }
                if (_planifierRetour) {
                  if (_priseEnChargeRetourPersonnalisee && _departRetourCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saisissez l\'adresse de prise en charge du retour.'),
                        backgroundColor: Color(0xFFD4AF37),
                      ),
                    );
                    return;
                  }
                  if (_dateRetourCtrl.text.trim().isEmpty || _heureRetourCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Renseignez la date et l\'heure du trajet retour.'),
                        backgroundColor: Color(0xFFD4AF37),
                      ),
                    );
                    return;
                  }
                }

                final devis = _devisVerrouille!;
                final phoneSaisi = _phoneCtrl.text.trim();
                final champsCommuns = {
                  'client': _clientCtrl.text.trim().toUpperCase(),
                  'email': _emailCtrl.text.trim(),
                  if (phoneSaisi.isNotEmpty) 'phone': phoneSaisi,
                  'prix': devis.prix,
                  'libelleTarif': devis.libelle,
                  'statut': 'PLANIFIÉ',
                  'passagers': 1,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                await widget.missionsRef.add({
                  ...champsCommuns,
                  'heure': _heureCtrl.text.trim(),
                  'date': _dateCtrl.text.trim(),
                  'depart': _departCtrl.text.trim(),
                  'destination': _destCtrl.text.trim().toUpperCase(),
                  'type': 'INSTANTANÉE',
                });

                if (_planifierRetour) {
                  final prixRetourRemise = KeleganceTarif.appliquerRemiseRetour(devis.prix);
                  await widget.missionsRef.add({
                    ...champsCommuns,
                    'heure': _heureRetourCtrl.text.trim(),
                    'date': _dateRetourCtrl.text.trim(),
                    'depart': _departRetourEffectif,
                    'destination': _destinationRetourEffectif.toUpperCase(),
                    'prix': prixRetourRemise,
                    'prixBrutRetour': devis.prix,
                    'remiseRetour': KeleganceTarif.tauxRemiseRetourAllerRetour,
                    'type': 'BON DE COMMANDE RETOUR',
                  });
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _planifierRetour
                          ? 'Réservation aller & retour enregistrées (tarif figé).'
                          : 'Réservation instantanée enregistrée (tarif figé).',
                    ),
                    backgroundColor: const Color(0xFFD4AF37),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Confirmer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Itinéraire in-app (Directions API) — sans Navigator ni GPS externe.
abstract final class KeleganceItineraireInApp {
  static List<LatLng> decoderPolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  static Future<({
    List<LatLng> points,
    String resume,
    LatLng origine,
    LatLng destination,
  })?> charger(String origin, String destination) async {
    final o = origin.trim();
    final d = destination.trim();
    if (o.isEmpty || d.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${Uri.encodeComponent(o)}'
        '&destination=${Uri.encodeComponent(d)}'
        '&mode=driving'
        '&language=fr'
        '&key=${KeleganceConfig.googleMapsApiKey}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;

      final leg = legs.first as Map<String, dynamic>;
      final distance = leg['distance']?['text']?.toString() ?? '';
      final duration = leg['duration']?['text']?.toString() ?? '';
      final resume = [distance, duration].where((e) => e.isNotEmpty).join(' · ');

      final poly = route['overview_polyline']?['points']?.toString();
      if (poly == null || poly.isEmpty) return null;

      final start = leg['start_location'] as Map<String, dynamic>;
      final end = leg['end_location'] as Map<String, dynamic>;

      return (
        points: decoderPolyline(poly),
        resume: resume.isNotEmpty ? resume : 'Itinéraire calculé',
        origine: LatLng(
          (start['lat'] as num).toDouble(),
          (start['lng'] as num).toDouble(),
        ),
        destination: LatLng(
          (end['lat'] as num).toDouble(),
          (end['lng'] as num).toDouble(),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceItineraireInApp: $e');
      return null;
    }
  }
}

/// Lancement navigation externe + retour au premier plan (Android).
abstract final class KeleganceNavigation {
  static const MethodChannel channel = MethodChannel('com.example.kelegance_neuf/navigation');
  static const MethodChannel overlayChannel = MethodChannel('com.example.kelegance_neuf/overlay');
  static const String googleMapsPackage = 'com.google.android.apps.maps';
  static const String wazePackage = 'com.waze';

  /// Hub transport (gare / aéroport) — navigation intent classique.
  static bool estHubTransport(String adresse) {
    final t = adresse.toLowerCase();
    return t.contains('gare') ||
        t.contains('aéroport') ||
        t.contains('aeroport') ||
        t.contains('cdg') ||
        t.contains('roissy') ||
        t.contains('charles de gaulle') ||
        t.contains('orly') ||
        t.contains('beauvais') ||
        t.contains('montparnasse') ||
        t.contains('saint-lazare') ||
        t.contains('gare de lyon') ||
        t.contains('austerlitz') ||
        t.contains('bercy') ||
        t.contains('gare du nord') ||
        t.contains('gare de l\'est') ||
        t.contains('rungis') ||
        t.contains('marché international') ||
        t.contains('marche international');
  }

  /// v4.0.0 — Adresse complète pour guidage (adresseArrivee hors hubs).
  static String resoudreAdresseCourse(Map<String, dynamic> course, {required bool versArrivee}) {
    if (versArrivee) {
      final destination = course['destination']?.toString().trim() ?? '';
      final adresseArrivee = course['adresseArrivee']?.toString().trim() ?? '';
      if (estHubTransport(destination)) return destination;
      if (adresseArrivee.isNotEmpty) return adresseArrivee;
      return destination;
    }
    return course['depart']?.toString().trim() ?? '';
  }

  /// Schéma URI direct — jamais d'URL https (évite pop-up navigateur sur PWA).
  static String construireUriNavigationNative(String adresse) {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return '';

    final match = RegExp(r'^(-?\d+\.?\d*)\s*[,;]\s*(-?\d+\.?\d*)$').firstMatch(trimmed);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        return 'google.navigation:q=$lat,$lng&mode=d';
      }
    }

    return 'googlemaps://?q=${Uri.encodeComponent(trimmed)}';
  }

  static Future<void> ouvrirAppleMaps(String adresse) async {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.parse('maps://?daddr=${Uri.encodeComponent(trimmed)}&dirflg=d');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await launchUrl(
      Uri.parse('https://maps.apple.com/?daddr=${Uri.encodeComponent(trimmed)}&dirflg=d'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> ouvrirGoogleMaps(String adresse) async {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return;

    if (kIsWeb) {
      KeleganceMapsLaunch.ouvrirNatif(trimmed);
      return;
    }

    if (keleganceEstAndroid) {
      final uriNative = construireUriNavigationNative(trimmed);
      if (await lancerAndroid(package: googleMapsPackage, uri: uriNative)) return;
    }

    final uriNative = Uri.parse(construireUriNavigationNative(trimmed));
    try {
      final ouvert = await launchUrl(uriNative, mode: LaunchMode.externalApplication);
      if (ouvert) return;
    } catch (_) {}

    final uriNav = Uri.parse('google.navigation:q=${Uri.encodeComponent(trimmed)}&mode=d');
    try {
      final ouvert = await launchUrl(uriNav, mode: LaunchMode.externalApplication);
      if (ouvert) return;
    } catch (_) {}

    final uriIos = Uri.parse(
      'comgooglemaps://?daddr=${Uri.encodeComponent(trimmed)}&directionsmode=driving',
    );
    try {
      await launchUrl(uriIos, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static Future<bool> lancerAndroid({required String package, required String uri}) async {
    if (!keleganceEstAndroid) return false;
    try {
      final ok = await channel.invokeMethod<bool>('launchNavigation', {'package': package, 'uri': uri});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ramenerAuPremierPlan() async {
    if (!keleganceEstAndroid) return false;
    try {
      final ok = await overlayChannel.invokeMethod<bool>('bringToFront');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}

// --- 2. Console chauffeur v7.0.0 Élite (gestion réservations + GPS destination cliquable) ---
enum _EcranChauffeur { accueil, suiviHistorique, revenus, reservations, profil, parametres, revenusFactures, bonsRetour }

enum _PeriodeRevenu { semaine, mois }

/// Courses tests du jour — intégrées à l'historique journalier chauffeur (v6.4.0).
abstract final class KeleganceHistoriqueDemo {
  static List<Map<String, dynamic>> coursesTestAujourdhui() {
    final today = KeleganceMissionTri.formaterDateFirestore(DateTime.now());
    return [
      {
        'demo': true,
        'depart': 'Chatou',
        'destination': 'Aéroport Roissy CDG',
        'heure': '08:30',
        'date': today,
        'statut': 'TERMINÉ',
        'prix': 89.0,
        'client': 'Caroline G.',
        'libelleTarif': KeleganceConfig.libelleForfaitAeroGare,
      },
      {
        'demo': true,
        'depart': 'Paris 17ème',
        'destination': 'Gare de Lyon',
        'heure': '11:45',
        'date': today,
        'statut': 'TERMINÉ',
        'prix': 28.50,
        'client': 'Guillaume L.',
        'libelleTarif': 'Tarif intelligent · 15 € min / 1,80 €/km',
      },
    ];
  }
}
class _PageConsoleState extends State<PageConsole> with WidgetsBindingObserver {
  _EcranChauffeur _ecran = _EcranChauffeur.accueil;
  bool _isOnline = false;
  bool _showCA = true;
  double _caJournalier = 0.0;
  double _volumeAlerte = 1.0;
  String _gpsDefaut = KeleganceConsolePrefs.gpsGoogleMaps;
  bool _gpsAutomatique = true;
  bool _statutAutomatique = false;
  LatLng? _latLngPriseEnCharge;
  LatLng? _latLngDestination;
  bool _statutAutoSurPlaceDeclenche = false;
  _PeriodeRevenu _periodeRevenu = _PeriodeRevenu.semaine;
  DateTime _jourRevenuSelectionne = DateTime.now();
  StreamSubscription<KeleganceMissionsSnapshot>? _abonnementLiveMissions;
  StreamSubscription<Position>? _abonnementGps;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _abonnementSollicitationDispatch;
  void Function()? _annulerDroitsAcces;
  Timer? _delaiSimulationAlerte;

  final Set<String> _missionsDejaAlertees = {};
  /// Garde anti-doublon — une seule alerte course visible à la fois (Stack, pas showDialog).
  bool _alerteCourseAffichee = false;
  bool _alertesInitialisees = false;
  String? _alerteCourseDocId;
  Map<String, dynamic>? _alerteCourseDonnees;
  bool _alerteCourseSimulation = false;
  int? _alerteCourseMinutesApproche;
  bool _alerteCourseCalculEnCours = false;
  bool _sosAffiche = false;

  /// Aucune modale bloquante simultanée (course + SOS).
  bool get _modaleConsoleBloquante => _alerteCourseAffichee || _sosAffiche;

  /// Garde synchrone avant toute alerte course (Stack ou showDialog réglementaire).
  bool _peutAfficherAlerteCourse() =>
      mounted && !_alerteCourseAffichee && !_sosAffiche;

  final CollectionReference _missionsRef = FirebaseFirestore.instance.collection('missions');
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(48.8566, 2.3522);
  double _currentHeading = 0.0;

  Map<String, dynamic>? _activeCourseData;
  String? _activeCourseId;
  String? _telephoneClientCourse;
  String _currentStep = "AUCUNE"; // AUCUNE, EN_ROUTE, SUR_PLACE, EN_COURSE

  bool _overlayCourseVisible = false;
  bool _demarrageCourseEnCours = false;
  bool _showRecenterButton = false;
  bool _recentrageProgramme = false;
  bool _carteManipuleeManuellement = false;
  LatLng? _dernierCentreCarte;
  String _nomProfilChauffeur = '—';

  bool _guidageInAppOuvert = false;
  bool _guidageVersDestination = false;
  bool _guidageChargement = false;
  List<LatLng> _polyligneGuidage = [];
  Set<Marker> _markersGuidage = {};
  String _guidageResume = '';
  String _guidageAdresseCible = '';
  int _guidageGeneration = 0;

  final ScrollController _scrollHistorique = ScrollController();
  final ScrollController _scrollRevenus = ScrollController();
  final ScrollController _scrollProfil = ScrollController();
  final ScrollController _scrollParametres = ScrollController();
  final ScrollController _scrollAgendaActives = ScrollController();
  final ScrollController _scrollAgendaHistorique = ScrollController();
  final ScrollController _scrollGraphiqueRevenus = ScrollController();

  bool get _courseChauffeurActive => _currentStep != 'AUCUNE' && _activeCourseData != null;
  bool get _courseEnCours => _currentStep == 'EN_COURSE';
  /// v3.6.0 — Occupé : EN_ROUTE, SUR PLACE ou client à bord (EN_COURSE).
  bool get _chauffeurOccupe =>
      _currentStep == 'EN_ROUTE' ||
      _currentStep == 'SUR_PLACE' ||
      _currentStep == 'EN_COURSE';
  bool get _demarrageCourseBloque => !_isOnline || _chauffeurOccupe;

  bool get _overlayNavigationAutorise =>
      _courseChauffeurActive && (_currentStep == 'EN_ROUTE' || _currentStep == 'EN_COURSE');

  bool get _accesBrasDroit => KeleganceRoles.estBrasDroit();
  bool get _vueChauffeurRestreinte =>
      widget.forceVueChauffeurRestreinte || keleganceRouteChauffeurDriver();
  bool get _accesComplet => _accesBrasDroit && !_vueChauffeurRestreinte;

  Future<void> _synchroniserPresenceFirestore() async {
    await KelegancePresenceService.publier(
      enLigne: _isOnline,
      enCourse: _chauffeurOccupe,
      nom: FirebaseAuth.instance.currentUser?.displayName,
    );
  }

  @override
  void initState() {
    super.initState();
    _showRecenterButton = false;
    WidgetsBinding.instance.addObserver(this);
    if (widget.ouvrirDirectement) {
      unawaited(KeleganceDeepLink.consommerIntentGestion());
    }
    unawaited(
      KeleganceRoles.initialiserPourUtilisateurCourant().then((_) {
        if (!mounted) return;
        if (_vueChauffeurRestreinte || (!_accesComplet && widget.ouvrirDirectement)) {
          setState(() => _ecran = _EcranChauffeur.reservations);
        }
      }),
    );
    KeleganceOverlayBridge.init(_onOverlayDemandeOuvertureApp);
    if (keleganceEstAndroid) {
      unawaited(_verifierPermissionOverlay());
    }
    _configurerSuiviGPS();
    _demarrerEcouteLiveMissions();
    unawaited(KeleganceAudioAlertes.initialiser());
    unawaited(_chargerPreferencesConsole());
    unawaited(_chargerPresenceInitiale());
    unawaited(_chargerNomProfilChauffeur());
    unawaited(KeleganceRoles.initialiserPourUtilisateurCourant());
    _annulerDroitsAcces = KeleganceRoles.ecouterMisesAJour(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _abonnementSollicitationDispatch = KeleganceDispatchSollicitation.demarrerEcoute(context);
    });
  }

  Future<void> _chargerPresenceInitiale() async {
    final enLigne = await KelegancePresenceService.chargerEnLigne();
    if (!mounted || enLigne == null) return;
    setState(() => _isOnline = enLigne);
    await _synchroniserPresenceFirestore();
  }

  Future<void> _chargerNomProfilChauffeur() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      ]);
      final data = <String, dynamic>{
        ...?results[1].data(),
        ...?results[0].data(),
      };
      var nom = KeleganceBonCommandeService.extraireNomAffichage(data);
      if (nom == 'Client' || nom.isEmpty) {
        nom = user.displayName?.trim() ?? '';
      }
      if (nom.isEmpty) {
        final email = user.email?.trim();
        if (email != null && email.contains('@')) {
          nom = email.split('@').first;
        }
      }
      if (!mounted) return;
      setState(() => _nomProfilChauffeur = nom.isNotEmpty ? nom : '—');
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance nom profil chauffeur: $e');
    }
  }

  Future<void> _chargerPreferencesConsole() async {
    final prefs = await KeleganceConsolePrefs.charger();
    if (!mounted) return;
    setState(() {
      _gpsAutomatique = prefs.gpsAutomatique;
      _statutAutomatique = prefs.statutAutomatique;
      _gpsDefaut = prefs.gpsDefaut;
    });
    KeleganceAudioAlertes.definirVolumeAlerte(_volumeAlerte);
  }

  Future<void> _sauvegarderPreferencesConsole() async {
    await KeleganceConsolePrefs.sauvegarder(
      gpsAutomatique: _gpsAutomatique,
      statutAutomatique: _statutAutomatique,
      gpsDefaut: _gpsDefaut,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres enregistrés.'),
        backgroundColor: Color(0xFFD4AF37),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KeleganceOverlayBridge.dispose();
    unawaited(_fermerOverlayCourse());
    _delaiSimulationAlerte?.cancel();
    _abonnementLiveMissions?.cancel();
    _abonnementSollicitationDispatch?.cancel();
    _annulerDroitsAcces?.call();
    _abonnementGps?.cancel();
    _mapController?.dispose();
    _scrollHistorique.dispose();
    _scrollRevenus.dispose();
    _scrollProfil.dispose();
    _scrollParametres.dispose();
    _scrollAgendaActives.dispose();
    _scrollAgendaHistorique.dispose();
    _scrollGraphiqueRevenus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_overlayNavigationAutorise) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_afficherOverlayNavigation());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_fermerOverlayCourse());
    }
  }

  Future<void> _verifierPermissionOverlay() async {
    await KeleganceOverlayCourse.initialiserPermissions();
  }

  void _synchroniserOverlayNavigation() {
    if (!keleganceEstAndroid) return;
    if (_overlayNavigationAutorise) {
      unawaited(_afficherOverlayNavigation());
    } else {
      unawaited(_fermerOverlayCourse());
    }
  }

  /// Affiche la bulle overlay — déclenchée immédiatement au lancement Maps (v3.1.2).
  Future<void> _afficherOverlayNavigation() async {
    if (!keleganceEstAndroid || !_overlayNavigationAutorise) return;
    var perm = await SystemAlertWindow.checkPermissions(prefMode: KeleganceOverlayCourse.prefMode);
    if (perm != true) {
      await SystemAlertWindow.requestPermissions(prefMode: KeleganceOverlayCourse.prefMode);
      perm = await SystemAlertWindow.checkPermissions(prefMode: KeleganceOverlayCourse.prefMode);
      if (perm != true) return;
    }
    if (_overlayCourseVisible) return;
    await SystemAlertWindow.showSystemWindow(
      height: KeleganceOverlayCourse.bubbleHeight,
      width: KeleganceOverlayCourse.bubbleWidth,
      gravity: SystemWindowGravity.TRAILING,
      prefMode: KeleganceOverlayCourse.prefMode,
      notificationTitle: 'KELEGANCE',
      notificationBody: 'Navigation active',
      layoutParamFlags: const [
        SystemWindowFlags.FLAG_NOT_FOCUSABLE,
        SystemWindowFlags.FLAG_NOT_TOUCH_MODAL,
      ],
    );
    if (!mounted) return;
    _overlayCourseVisible = true;
  }

  Future<void> _fermerOverlayCourse() async {
    if (!keleganceEstAndroid || !_overlayCourseVisible) return;
    await SystemAlertWindow.closeSystemWindow(prefMode: KeleganceOverlayCourse.prefMode);
    if (!mounted) return;
    _overlayCourseVisible = false;
  }

  void _onOverlayDemandeOuvertureApp() {
    unawaited(KeleganceNavigation.ramenerAuPremierPlan());
    unawaited(_fermerOverlayCourse());
  }

  void _demarrerEcouteLiveMissions() {
    _abonnementLiveMissions?.cancel();
    _abonnementLiveMissions = KeleganceMissionsService.flux.listen(
      (snapshot) {
        if (!mounted) return;
        _traiterAlertesMissions(snapshot);
        _recalculerCaJournalier(snapshot.docs);
        _synchroniserCourseActiveDepuisFirestore(snapshot);
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Kelegance live missions console: $e');
      },
    );
  }

  void _synchroniserCourseActiveDepuisFirestore(KeleganceMissionsSnapshot snapshot) {
    final id = _activeCourseId;
    if (id == null) return;

    QueryDocumentSnapshot? doc;
    for (final d in snapshot.docs) {
      if (d.id == id) {
        doc = d;
        break;
      }
    }

    if (doc == null) {
      if (_currentStep != 'AUCUNE') {
        setState(() {
          _currentStep = 'AUCUNE';
          _activeCourseId = null;
          _activeCourseData = null;
          _telephoneClientCourse = null;
        });
      }
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final etape = KeleganceMissionsService.etapeDepuisStatut(data['statut']?.toString());
    if (etape == null) return;

    if (etape == 'AUCUNE') {
      setState(() {
        _currentStep = 'AUCUNE';
        _activeCourseId = null;
        _activeCourseData = null;
        _telephoneClientCourse = null;
      });
      unawaited(_fermerOverlayCourse());
      return;
    }

    if (etape != _currentStep || data['statut'] != _activeCourseData?['statut']) {
      setState(() {
        _currentStep = etape;
        _activeCourseData = {...data};
      });
      _synchroniserOverlayNavigation();
    }
  }

  void _traiterAlertesMissions(KeleganceMissionsSnapshot snapshot) {
    if (!_alertesInitialisees) {
      for (final doc in snapshot.docs) {
        _missionsDejaAlertees.add(doc.id);
      }
      _alertesInitialisees = true;
      return;
    }

    if (!_isOnline || _chauffeurOccupe || _modaleConsoleBloquante) return;

    for (final change in snapshot.changes) {
      if (change.type != DocumentChangeType.added && change.type != DocumentChangeType.modified) continue;
      final raw = change.doc.data();
      if (raw is! Map<String, dynamic>) continue;
      final data = raw;

      final statut = (data['statut']?.toString() ?? '').toUpperCase().trim();
      if (statut != 'EN ATTENTE') continue;
      if (!_accesBrasDroit) {
        if (!KeleganceRoles.missionAssigneeAuCollaborateur(data)) continue;
      }
      if (_missionsDejaAlertees.contains(change.doc.id)) continue;
      if (_modaleConsoleBloquante || !_peutAfficherAlerteCourse()) return;

      _missionsDejaAlertees.add(change.doc.id);
      unawaited(_afficherPopupAlerteCourse(docId: change.doc.id, data: data));
      return;
    }
  }

  Future<int> _calculerMinutesApproche(String adresseDepart) async {
    final depart = adresseDepart.trim();
    if (depart.isEmpty) return 0;

    try {
      final origine = '${_currentPosition.latitude},${_currentPosition.longitude}';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${Uri.encodeComponent(origine)}'
        '&destinations=${Uri.encodeComponent(depart)}'
        '&mode=driving'
        '&language=fr'
        '&units=metric'
        '&key=${KeleganceConfig.googleMapsApiKey}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return 15;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return 15;

      final elements = (json['rows'] as List?)?.first?['elements'] as List?;
      final element = elements?.isNotEmpty == true ? elements!.first as Map<String, dynamic> : null;
      if (element == null || element['status'] != 'OK') return 15;

      final seconds = (element['duration'] as Map)['value'] as int;
      return (seconds / 60).ceil().clamp(1, 999);
    } catch (_) {
      return 15;
    }
  }

  void _lancerGoogleMapsCourse(String adresse) {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return;
    if (_overlayNavigationAutorise) {
      unawaited(_afficherOverlayNavigation());
    }
    unawaited(KeleganceNavigation.ouvrirGoogleMaps(trimmed));
  }

  void _lancerGpsPrioritaire(String adresse) {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return;
    if (_overlayNavigationAutorise) {
      unawaited(_afficherOverlayNavigation());
    }

    if (_gpsDefaut == KeleganceConsolePrefs.gpsWaze) {
      unawaited(_ouvrirWazeNavigation(trimmed));
      return;
    }
    if (_gpsDefaut == KeleganceConsolePrefs.gpsAppleMaps) {
      unawaited(KeleganceNavigation.ouvrirAppleMaps(trimmed));
      return;
    }

    unawaited(KeleganceNavigation.ouvrirGoogleMaps(trimmed));
  }

  void _declencherGpsExternePourEtapeCourante() {
    final adresse = _adresseNavigationCourante();
    if (adresse.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Adresse de navigation indisponible pour cette étape.'),
        ),
      );
      return;
    }
    _lancerGpsPrioritaire(adresse);
  }

  void _lancerNavigationAutomatiqueCourse() {
    if (!_gpsAutomatique) return;
    final adresse = _adresseNavigationCourante();
    if (adresse.isNotEmpty) {
      _lancerGoogleMapsCourse(adresse);
    }
  }

  Future<LatLng?> _geocoderAdresseMission(String adresse) async {
    final texte = adresse.trim();
    if (texte.isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(texte)}'
        '&language=fr'
        '&key=${KeleganceConfig.googleMapsApiKey}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;
      final loc = (json['results'] as List?)?.first?['geometry']?['location'] as Map?;
      if (loc == null) return null;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<void> _preparerGeocodageCourse(Map<String, dynamic> data) async {
    _latLngPriseEnCharge = null;
    _latLngDestination = null;
    _statutAutoSurPlaceDeclenche = false;
    final depart = data['depart']?.toString() ?? '';
    final destination = data['destination']?.toString() ?? '';
    final results = await Future.wait([
      _geocoderAdresseMission(depart),
      _geocoderAdresseMission(destination),
    ]);
    if (!mounted) return;
    _latLngPriseEnCharge = results[0];
    _latLngDestination = results[1];
  }

  void _evaluerStatutAutomatique() {
    if (!_statutAutomatique || _latLngPriseEnCharge == null) return;
    if (_currentStep != 'EN_ROUTE' || _statutAutoSurPlaceDeclenche) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition.latitude,
      _currentPosition.longitude,
      _latLngPriseEnCharge!.latitude,
      _latLngPriseEnCharge!.longitude,
    );
    if (distance <= 180) {
      _statutAutoSurPlaceDeclenche = true;
      unawaited(_passerSurPlaceManuel());
    }
  }

  void _fermerGuidageInApp() {
    if (!_guidageInAppOuvert && _polyligneGuidage.isEmpty) return;
    setState(() {
      _guidageInAppOuvert = false;
      _guidageChargement = false;
      _polyligneGuidage = [];
      _markersGuidage = {};
      _guidageResume = '';
      _guidageAdresseCible = '';
    });
  }

  void _ouvrirGuidageInApp({required bool versDestination}) {
    if (_activeCourseData == null) return;

    final adresse = KeleganceNavigation.resoudreAdresseCourse(
      _activeCourseData!,
      versArrivee: versDestination,
    );
    if (adresse.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            versDestination
                ? 'Adresse de destination indisponible.'
                : 'Adresse de prise en charge indisponible.',
          ),
        ),
      );
      return;
    }

    // Déjà ouvert sur le même mode : ne pas basculer (évite l'effet double-clic).
    if (_guidageInAppOuvert && _guidageVersDestination == versDestination && !_guidageChargement) {
      return;
    }

    setState(() {
      _guidageInAppOuvert = true;
      _guidageVersDestination = versDestination;
      _guidageAdresseCible = adresse;
      _guidageChargement = true;
      _guidageResume = '';
      _polyligneGuidage = [];
      _markersGuidage = {};
    });

    unawaited(_chargerItineraireInApp(versDestination));
  }

  Future<void> _chargerItineraireInApp(bool versDestination) async {
    final generation = ++_guidageGeneration;
    final origine = '${_currentPosition.latitude},${_currentPosition.longitude}';
    final destination = _guidageAdresseCible;

    final result = await KeleganceItineraireInApp.charger(origine, destination);
    if (!mounted || generation != _guidageGeneration) return;

    if (result == null) {
      setState(() => _guidageChargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Impossible de calculer l\'itinéraire. Réessayez.'),
        ),
      );
      return;
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('guidage_origine'),
        position: result.origine,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('guidage_destination'),
        position: result.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };

    setState(() {
      _guidageChargement = false;
      _polyligneGuidage = result.points;
      _markersGuidage = markers;
      _guidageResume = result.resume;
    });

    if (_ecran == _EcranChauffeur.accueil) {
      unawaited(_ajusterCameraSurItineraire(result.points));
    }
  }

  Future<void> _ajusterCameraSurItineraire(List<LatLng> points) async {
    final controller = _mapController;
    if (controller == null || points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          72,
        ),
      );
    } catch (_) {
      await controller.animateCamera(CameraUpdate.newLatLng(points[points.length ~/ 2]));
    }
  }

  /// Guidage vers la prise en charge (EN_ROUTE / SUR PLACE) — in-app uniquement.
  void _relancerGpsVersClient() => _ouvrirGuidageInApp(versDestination: false);

  /// Guidage vers la destination finale (EN_COURSE) — in-app uniquement.
  void _relancerGpsDestinationFinale() => _ouvrirGuidageInApp(versDestination: true);

  void _accepterCourseDepuisAlerte(String docId, Map<String, dynamic> data, {bool simulation = false}) {
    if (!_isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Passez En Ligne pour accepter la course.'),
          ),
        );
      }
      return;
    }
    if (_chauffeurOccupe) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Terminez la mission active avant d\'en accepter une autre.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _demarrageCourseEnCours = true;
      _activerVueCourseImmersive();
      _fermerGuidageInApp();
      _activeCourseId = docId;
      _activeCourseData = {...data, 'statut': 'EN_ROUTE'};
      _currentStep = 'EN_ROUTE';
      _telephoneClientCourse = KeleganceCommunication.extraireNumeroMission(data);
    });

    if (!simulation) {
      unawaited(_mettreAJourStatutCourse(
        docId,
        'EN_ROUTE',
        messageClient: KeleganceCommunication.messageClientEnRoute,
      ));
      unawaited(_enrichirMissionChauffeur(docId));
    }

    if (_telephoneClientCourse == null) {
      unawaited(KeleganceCommunication.resoudreNumeroClient(data).then((resolu) {
        if (mounted && resolu != null) {
          setState(() => _telephoneClientCourse = resolu);
        }
      }));
    }

    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _demarrageCourseEnCours = false);
    });

    if (_gpsAutomatique) {
      _lancerNavigationAutomatiqueCourse();
    }
    unawaited(_preparerGeocodageCourse(data));
  }

  void _fermerAlerteCourseAffichee() {
    if (!_alerteCourseAffichee) return;
    setState(() {
      _alerteCourseAffichee = false;
      _alerteCourseDocId = null;
      _alerteCourseDonnees = null;
      _alerteCourseSimulation = false;
      _alerteCourseMinutesApproche = null;
      _alerteCourseCalculEnCours = false;
    });
  }

  Future<void> _afficherPopupAlerteCourse({
    required String docId,
    required Map<String, dynamic> data,
    bool simulation = false,
  }) async {
    if (!_peutAfficherAlerteCourse()) return;

    // Verrou synchrone immédiat — aucun second showDialog / overlay ne peut passer.
    _alerteCourseAffichee = true;
    _alerteCourseCalculEnCours = true;
    _alerteCourseDocId = docId;
    _alerteCourseDonnees = data;
    _alerteCourseSimulation = simulation;
    _alerteCourseMinutesApproche = null;
    setState(() {});

    unawaited(KeleganceAudioAlertes.playInstantRequestSound());

    final minutesApproche = await _calculerMinutesApproche(data['depart']?.toString() ?? '');
    if (!mounted || !_alerteCourseAffichee || _alerteCourseDocId != docId) return;

    setState(() {
      _alerteCourseMinutesApproche = minutesApproche;
      _alerteCourseCalculEnCours = false;
    });
  }

  void _refuserCourseDepuisAlerte() {
    final docId = _alerteCourseDocId;
    final simulation = _alerteCourseSimulation;
    unawaited(KeleganceAudioAlertes.stopInstantRequestSound());
    if (docId != null && !simulation) {
      unawaited(FirebaseFirestore.instance.collection('missions').doc(docId).update({'statut': 'ANNULÉ'}));
    }
    _fermerAlerteCourseAffichee();
  }

  void _accepterCourseDepuisAlerteOverlay() {
    final docId = _alerteCourseDocId;
    final data = _alerteCourseDonnees;
    final simulation = _alerteCourseSimulation;
    if (docId == null || data == null) {
      _fermerAlerteCourseAffichee();
      return;
    }
    unawaited(KeleganceAudioAlertes.stopInstantRequestSound());
    _fermerAlerteCourseAffichee();
    _accepterCourseDepuisAlerte(docId, data, simulation: simulation);
  }

  Widget _buildOverlayAlerteCourse() {
    final data = _alerteCourseDonnees;
    if (data == null) return const SizedBox.shrink();

    final villeDepart = KeleganceAdresse.extraireVille(data['depart']?.toString() ?? '');
    final destinationMacro = KeleganceAdresse.formaterDestinationMacro(data['destination']?.toString() ?? '');
    final prix = (data['prix'] as num?)?.toDouble();
    final ventilation = prix != null ? KeleganceCommission.ventiler(prix) : null;
    final prixText = prix != null ? prix.toStringAsFixed(2) : '—';
    final fraisText = ventilation != null ? ventilation.fraisService.toStringAsFixed(2) : '—';
    final netText = ventilation != null ? ventilation.netChauffeur.toStringAsFixed(2) : '—';
    final minutes = _alerteCourseMinutesApproche;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: KeleganceThemePremium.fond,
                  borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium + 6),
                  border: Border.all(color: KeleganceThemePremium.or.withOpacity(0.55), width: 0.9),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_alerteCourseCalculEnCours || minutes == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: KeleganceThemePremium.or),
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        'APPROCHE · $minutes MIN',
                        textAlign: TextAlign.center,
                        style: KeleganceThemePremium.titreAlerte(size: 22),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'DE · $villeDepart',
                        textAlign: TextAlign.center,
                        style: KeleganceThemePremium.titreAlerte(size: 17).copyWith(color: KeleganceThemePremium.texteDiscret),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'VERS · $destinationMacro',
                        textAlign: TextAlign.center,
                        style: KeleganceThemePremium.titreAlerte(size: 17).copyWith(
                          color: KeleganceThemePremium.textePrincipal,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      KeleganceThemePremium.bandeauNetChauffeur(
                        netText: netText,
                        prixText: prixText,
                        fraisText: ventilation != null ? fraisText : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: KeleganceThemePremium.boutonRefus(),
                        onPressed: _alerteCourseCalculEnCours ? null : _refuserCourseDepuisAlerte,
                        child: const Text('REFUSER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 1.6)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: KeleganceThemePremium.boutonAccept(),
                        onPressed: _alerteCourseCalculEnCours ? null : _accepterCourseDepuisAlerteOverlay,
                        child: const Text('ACCEPTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _simulerVraieAlerteCourse() {
    if (!_peutAfficherAlerteCourse()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une alerte est déjà affichée.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _delaiSimulationAlerte?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Simulation : alerte course dans 5 secondes...'),
        backgroundColor: Color(0xFFD4AF37),
        duration: Duration(seconds: 4),
      ),
    );
    _delaiSimulationAlerte = Timer(const Duration(seconds: 5), () {
      if (!_peutAfficherAlerteCourse()) return;
      unawaited(_afficherPopupAlerteCourse(
        docId: 'simulation_kelegance',
        simulation: true,
        data: {
          'depart': '12 Avenue de la République, Rueil-Malmaison',
          'destination': 'Aéroport Roissy Charles de Gaulle',
          'prix': 65.0,
          'statut': 'EN ATTENTE',
          'type': 'INSTANTANÉE',
        },
      ));
    });
  }

  LocationSettings _parametresGpsHauteFrequence() {
    if (keleganceEstAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (keleganceEstIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
  }

  void _appliquerPositionChauffeur(LatLng pos, double heading) {
    final carteVisible = _ecran == _EcranChauffeur.accueil;
    final positionChangee =
        (_currentPosition.latitude - pos.latitude).abs() > 0.00001 ||
        (_currentPosition.longitude - pos.longitude).abs() > 0.00001 ||
        (_currentHeading - heading).abs() > 0.5;
    if (!positionChangee) return;

    _currentPosition = pos;
    _currentHeading = heading;
    _evaluerStatutAutomatique();
    if (carteVisible) {
      setState(() {});
      if (!_carteManipuleeManuellement) {
        unawaited(_animerCameraSurChauffeur());
      }
    }
  }

  Future<void> _animerCameraSurChauffeur() async {
    final controller = _mapController;
    if (controller == null || _carteManipuleeManuellement || _recentrageProgramme) return;
    _recentrageProgramme = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: _zoomCarteChauffeur,
            tilt: _tiltCarteChauffeur,
            bearing: _currentHeading,
          ),
        ),
      );
    } finally {
      _recentrageProgramme = false;
      if (mounted) {
        _majVisibiliteBoutonRecentrage(_currentPosition);
      }
    }
  }

  Future<void> _configurerSuiviGPS() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    await _abonnementGps?.cancel();
    _abonnementGps = Geolocator.getPositionStream(
      locationSettings: _parametresGpsHauteFrequence(),
    ).listen((position) {
      if (!mounted) return;
      final pos = LatLng(position.latitude, position.longitude);
      final heading = position.heading >= 0 ? position.heading : _currentHeading;
      _appliquerPositionChauffeur(pos, heading);
    });
  }

  Future<void> _passerSurPlaceManuel() async {
    if (_activeCourseId == null || _currentStep != 'EN_ROUTE') return;
    await _mettreAJourStatutCourse(
      _activeCourseId!,
      'SUR PLACE',
      messageClient: KeleganceCommunication.messageClientSurPlace,
    );
    if (!mounted) return;
    setState(() {
      _currentStep = 'SUR_PLACE';
      _activeCourseData = {..._activeCourseData!, 'statut': 'SUR PLACE'};
    });
    unawaited(_fermerOverlayCourse());
  }


  DateTime? _dateMissionVersDateTime(Map<String, dynamic> data) {
    final brut = data['date']?.toString().trim() ?? '';
    if (brut.isNotEmpty) {
      final iso = DateTime.tryParse(brut);
      if (iso != null) return iso;
      final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(brut);
      if (match != null) {
        return DateTime(int.parse(match.group(3)!), int.parse(match.group(2)!), int.parse(match.group(1)!));
      }
    }
    final ts = data['pipeline_updated_at'] ?? data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  bool _estAujourdhui(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  DateTime? _dateClotureCourse(Map<String, dynamic> data) {
    final ts = data['pipeline_updated_at'];
    if (ts is Timestamp) return ts.toDate();
    return _dateMissionVersDateTime(data);
  }

  void _recalculerCaJournalier(List<QueryDocumentSnapshot> docs) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    final uid = user?.uid;
    var total = 0.0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!_accesComplet &&
          !KeleganceRoles.missionAssigneeAuCollaborateur(
            data,
            email: email,
            nom: _nomProfilChauffeur,
            uid: uid,
          )) {
        continue;
      }
      final statut = (data['statut']?.toString() ?? '').toUpperCase().replaceAll('É', 'E').trim();
      if (statut != 'TERMINE' && statut != 'TERMINÉ') continue;
      final dateCloture = _dateClotureCourse(data);
      if (dateCloture == null || !_estAujourdhui(dateCloture)) continue;
      final prix = data['prix'];
      if (prix is num) total += prix.toDouble();
    }
    if (mounted && (total - _caJournalier).abs() > 0.001) {
      _caJournalier = total;
      if (_ecran == _EcranChauffeur.accueil) {
        setState(() {});
      }
    }
  }

  String get _libelleCaBandeau => _accesComplet ? 'CA Jour : ' : 'Mon CA du Jour : ';

  String get _caJournalierAffiche => '${_caJournalier.toStringAsFixed(2)} €';

  bool _estMissionHistorique(Map<String, dynamic> data) {
    final statut = (data['statut']?.toString() ?? '').toUpperCase().replaceAll('É', 'E').trim();
    return statut == 'TERMINE' || statut == 'ANNULE' || statut.contains('ANNUL');
  }

  Widget _buildBandeauCaCentre() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Center(
        child: Material(
          color: _noirProfond.withOpacity(0.72),
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _orKelegance.withOpacity(0.45), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _libelleCaBandeau,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 0.4),
                ),
                Text(
                  _showCA ? _caJournalierAffiche : '•••• €',
                  style: const TextStyle(
                    color: _orKelegance,
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: _showCA ? 'Masquer le CA' : 'Afficher le CA',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() => _showCA = !_showCA),
                  icon: Icon(
                    _showCA ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _adresseNavigationCourante() {
    if (_activeCourseData == null) return '';
    if (_currentStep == 'EN_COURSE') {
      return _activeCourseData!['destination']?.toString().trim() ?? '';
    }
    return _activeCourseData!['depart']?.toString().trim() ?? '';
  }

  Future<void> _mettreAJourStatutCourse(
    String docId,
    String statut, {
    required String messageClient,
  }) async {
    await FirebaseFirestore.instance.collection('missions').doc(docId).update({
      'statut': statut,
      'pipeline_updated_at': FieldValue.serverTimestamp(),
      'notificationClient': messageClient,
      'notificationClientAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _prendreCourse(String docId, Map<String, dynamic> data) async {
    if (!_accesBrasDroit && !KeleganceRoles.missionAssigneeAuCollaborateur(data)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Cette course ne vous est pas assignée.'),
        ),
      );
      return;
    }
    if (!_isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Veuillez passer En Ligne pour commencer cette course.'),
          ),
        );
      }
      return;
    }
    if (_chauffeurOccupe) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Course en cours — terminez la mission active avant d\'en prendre une autre.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _activerVueCourseImmersive();
      _fermerGuidageInApp();
      _activeCourseId = docId;
      _activeCourseData = {...data, 'statut': 'EN_ROUTE'};
      _currentStep = 'EN_ROUTE';
      _telephoneClientCourse = KeleganceCommunication.extraireNumeroMission(data);
    });

    unawaited(_mettreAJourStatutCourse(
      docId,
      'EN_ROUTE',
      messageClient: KeleganceCommunication.messageClientEnRoute,
    ));
    unawaited(_enrichirMissionChauffeur(docId));

    if (_telephoneClientCourse == null) {
      unawaited(KeleganceCommunication.resoudreNumeroClient(data).then((resolu) {
        if (mounted && resolu != null) {
          setState(() => _telephoneClientCourse = resolu);
        }
      }));
    }

    if (_gpsAutomatique) {
      _lancerNavigationAutomatiqueCourse();
    }
    unawaited(_preparerGeocodageCourse(data));
  }

  Future<void> _clientABord() async {
    if (_activeCourseId == null || _activeCourseData == null) return;

    setState(() {
      _activerVueCourseImmersive();
      _currentStep = 'EN_COURSE';
      _activeCourseData = {..._activeCourseData!, 'statut': 'EN COURSE'};
    });

    unawaited(_mettreAJourStatutCourse(
      _activeCourseId!,
      'EN COURSE',
      messageClient: 'Votre chauffeur est en route vers votre destination.',
    ));

    if (_gpsAutomatique) {
      _lancerNavigationAutomatiqueCourse();
    }
  }

  Future<void> _terminerCourse() async {
    if (_activeCourseId == null || _activeCourseData == null) return;
    final docId = _activeCourseId!;
    final data = Map<String, dynamic>.from(_activeCourseData!);

    await _fermerOverlayCourse();
    _fermerGuidageInApp();

    // Débit Stripe avant clôture — seul point bloquant légitime
    if (KeleganceStripePaiement.estStripe(data)) {
      final prix = (data['prix'] as num?)?.toDouble() ?? 0.0;
      if (prix > 0) {
        final debite = await KeleganceStripePaiement.debiterFinDeCourse(context, montant: prix);
        if (!debite) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Débit Stripe annulé — course non clôturée.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }

    // Fermeture immédiate de l'écran course — la Cloud Function travaille en arrière-plan
    if (mounted) {
      setState(() {
        _currentStep = 'AUCUNE';
        _activeCourseId = null;
        _activeCourseData = null;
        _telephoneClientCourse = null;
        _latLngPriseEnCharge = null;
        _latLngDestination = null;
        _statutAutoSurPlaceDeclenche = false;
        _ecran = _EcranChauffeur.accueil;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course terminée — facture envoyée au client en arrière-plan.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    unawaited(_cloturerMissionEnArrierePlan(docId, data));
  }

  Future<void> _ouvrirGoogleMapsNavigation(String adresse) async {
    _lancerGoogleMapsCourse(adresse);
  }

  Future<void> _ouvrirWazeNavigation(String adresse) async {
    final trimmed = adresse.trim();
    if (trimmed.isEmpty) return;
    final uri = 'waze://?q=${Uri.encodeComponent(trimmed)}&navigate=yes';
    if (keleganceEstAndroid && await KeleganceNavigation.lancerAndroid(package: KeleganceNavigation.wazePackage, uri: uri)) {
      return;
    }
    await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
  }

  bool get _courseImmersive => _courseChauffeurActive;

  bool get _carteAccueilVisible => _ecran == _EcranChauffeur.accueil;

  void _naviguerVersEcran(_EcranChauffeur ecran) {
    if (ecran == _EcranChauffeur.revenusFactures && !_accesComplet) {
      keleganceAfficherRefusPermission(
        context,
        detail: 'Revenus & Factures — accès réservé aux Bras Droit.',
      );
      return;
    }
    if (ecran == _EcranChauffeur.bonsRetour && !_accesComplet) {
      keleganceAfficherRefusPermission(
        context,
        detail: 'Bons de commande retour — accès réservé aux Bras Droit.',
      );
      return;
    }
    setState(() => _ecran = ecran);
    if (ecran == _EcranChauffeur.accueil &&
        _guidageInAppOuvert &&
        _polyligneGuidage.length > 1) {
      unawaited(_ajusterCameraSurItineraire(_polyligneGuidage));
    }
  }

  void _retourAccueilChauffeur() {
    if (_ecran == _EcranChauffeur.accueil) return;
    setState(() => _ecran = _EcranChauffeur.accueil);
  }

  void _ouvrirPreferencesNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KeleganceEcranPreferencesNotifications(
          couleurAccent: _orKelegance,
          fond: _noirProfond,
        ),
      ),
    );
  }

  /// Masque l'agenda / réservations — affiche uniquement la carte pendant une course active.
  void _activerVueCourseImmersive() {
    if (_ecran == _EcranChauffeur.accueil) return;
    _ecran = _EcranChauffeur.accueil;
  }

  static const Color _orKelegance = Color(0xFFD4AF37);
  static const Color _noirProfond = Color(0xFF000000);
  static const double _zoomCarteChauffeur = 18.5;
  static const double _tiltCarteChauffeur = 58.0;
  static const double _paddingCarteBandeauCourse = 220.0;
  /// Padding bas carte — repousse le bandeau Google sous le panneau inférieur.
  static const double _paddingMasquageBandeauGoogle = 42.0;
  static const double _hauteurBarreNavChauffeur = 64.0;
  static const double _seuilDecalageRecentrageMetres = 28.0;

  double _paddingBasCarteGoogleMap() {
    if (_courseChauffeurActive) return _paddingCarteBandeauCourse;
    var padding = _paddingMasquageBandeauGoogle;
    if (!_courseImmersive) padding += _hauteurBarreNavChauffeur;
    return padding;
  }

  double _offsetBasPanneauGuidage() {
    if (_courseChauffeurActive) return _paddingCarteBandeauCourse;
    if (!_courseImmersive) return _hauteurBarreNavChauffeur + 8;
    return 8;
  }

  double _distanceCarteChauffeurMetres(LatLng mapCenter) {
    return Geolocator.distanceBetween(
      mapCenter.latitude,
      mapCenter.longitude,
      _currentPosition.latitude,
      _currentPosition.longitude,
    );
  }

  bool _carteDecaleeDuChauffeur(LatLng mapCenter) {
    return _distanceCarteChauffeurMetres(mapCenter) > _seuilDecalageRecentrageMetres;
  }

  void _majVisibiliteBoutonRecentrage(LatLng mapCenter) {
    if (_ecran != _EcranChauffeur.accueil || _recentrageProgramme) return;

    final decalee = _carteDecaleeDuChauffeur(mapCenter);
    if (decalee == _showRecenterButton && decalee == _carteManipuleeManuellement) return;

    setState(() {
      _showRecenterButton = decalee;
      _carteManipuleeManuellement = decalee;
    });
  }

  Widget _buildCarte3DFond() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1.0,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight + _paddingMasquageBandeauGoogle,
              child: GoogleMap(
                key: const ValueKey('kelegance_carte_chauffeur'),
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: _zoomCarteChauffeur,
                  tilt: _tiltCarteChauffeur,
                  bearing: _currentHeading,
                ),
                padding: EdgeInsets.only(bottom: _paddingBasCarteGoogleMap()),
                markers: _markersGuidage,
                polylines: _polyligneGuidage.isEmpty
                    ? const {}
                    : {
                        Polyline(
                          polylineId: const PolylineId('guidage_kelegance'),
                          points: _polyligneGuidage,
                          color: _orKelegance,
                          width: 5,
                        ),
                      },
                circles: const {},
                mapType: MapType.normal,
                style: KeleganceCarteStyle.sombreOr,
                buildingsEnabled: true,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                onCameraMove: (position) {
                  _dernierCentreCarte = position.target;
                  _majVisibiliteBoutonRecentrage(position.target);
                },
                onCameraIdle: () {
                  final centre = _dernierCentreCarte;
                  if (centre != null) {
                    _majVisibiliteBoutonRecentrage(centre);
                  }
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _recentrerCarteSurChauffeur() async {
    final controller = _mapController;
    if (controller == null) return;
    setState(() {
      _recentrageProgramme = true;
      _showRecenterButton = false;
      _carteManipuleeManuellement = false;
    });
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: _zoomCarteChauffeur,
            tilt: _tiltCarteChauffeur,
            bearing: _currentHeading,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _recentrageProgramme = false);
        _majVisibiliteBoutonRecentrage(_currentPosition);
      }
    }
  }

  Widget _buildBoutonRecentrerCarte() {
    if (!_showRecenterButton) return const SizedBox.shrink();

    final bas = _paddingBasCarteGoogleMap() + 16;
    return Positioned(
      right: 16,
      bottom: bas,
      child: Material(
        color: _noirProfond.withOpacity(0.88),
        elevation: 4,
        shape: const CircleBorder(
          side: BorderSide(color: _orKelegance, width: 0.7),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => unawaited(_recentrerCarteSurChauffeur()),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.my_location, color: _orKelegance, size: 22),
          ),
        ),
      ),
    );
  }

  InputDecoration _champReservation(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _orKelegance, fontSize: 11, fontWeight: FontWeight.w500),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _orKelegance.withOpacity(0.25), width: 0.6)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _orKelegance.withOpacity(0.75), width: 0.8)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
    );
  }

  void _showReservationInstantanee() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PageReservationInstantanee(missionsRef: _missionsRef),
      ),
    );
  }

  Future<void> _basculerModeClient() async {
    Navigator.pop(context);
    await AuthService.sauvegarderRoleSession('client');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KeleganceEcranProtege(child: PageClient())),
    );
    await AuthService.sauvegarderRoleSession('chauffeur');
  }

  Future<void> _deconnecterChauffeur() async {
    Navigator.pop(context);
    await AuthService().signOut();
  }

  Widget _drawerLienDirect({
    required IconData icone,
    required String titre,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (drawerContext) => ListTile(
        leading: Icon(icone, color: _orKelegance.withOpacity(0.85), size: 22),
        title: Text(
          titre,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        onTap: () {
          Navigator.pop(drawerContext);
          onTap();
        },
      ),
    );
  }

  Widget _buildDrawerChauffeur() {
    return Drawer(
      backgroundColor: _noirProfond,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: _orKelegance.withOpacity(0.35), width: 0.6)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _orKelegance.withOpacity(0.25), width: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KELEGANCE',
                      style: TextStyle(color: _orKelegance.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Console Chauffeur',
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    if (_accesComplet) ...[
                      const KelegancePresenceEquipe(compact: true),
                      Divider(height: 24, indent: 18, endIndent: 18, color: _orKelegance.withOpacity(0.2)),
                      _drawerLienDirect(
                        icone: Icons.group_add_outlined,
                        titre: 'Équipe — inviter un chauffeur',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KelegancePageInvitationEquipe()),
                        ),
                      ),
                    ],
                    _drawerLienDirect(
                      icone: Icons.assignment_outlined,
                      titre: 'Suivi & Historique',
                      onTap: () => _naviguerVersEcran(_EcranChauffeur.suiviHistorique),
                    ),
                    _drawerLienDirect(
                      icone: Icons.person_outline,
                      titre: 'Mon profil chauffeur',
                      onTap: () => _naviguerVersEcran(_EcranChauffeur.profil),
                    ),
                    _drawerLienDirect(
                      icone: Icons.bar_chart_outlined,
                      titre: 'Mes revenus Hebdo et mensuels',
                      onTap: () => _naviguerVersEcran(_EcranChauffeur.revenus),
                    ),
                    if (_accesComplet)
                      _drawerLienDirect(
                        icone: Icons.assignment_return_outlined,
                        titre: 'Bons de commande retour',
                        onTap: () => _naviguerVersEcran(_EcranChauffeur.bonsRetour),
                      ),
                    if (_accesComplet)
                      _drawerLienDirect(
                        icone: Icons.receipt_long_outlined,
                        titre: 'Revenus & Factures',
                        onTap: () => _naviguerVersEcran(_EcranChauffeur.revenusFactures),
                      ),
                    _drawerLienDirect(
                      icone: Icons.folder_special_outlined,
                      titre: 'Documents obligatoires chauffeur et conducteur',
                      onTap: () => keleganceAfficherDocumentsChauffeur(context),
                    ),
                    _drawerLienDirect(
                      icone: Icons.settings_outlined,
                      titre: "Paramètres de l'appli",
                      onTap: () => _naviguerVersEcran(_EcranChauffeur.parametres),
                    ),
                    _drawerLienDirect(
                      icone: Icons.help_outline,
                      titre: 'Aide',
                      onTap: () => keleganceAfficherAideSupport(context, chauffeur: true),
                    ),
                    if (_accesComplet) ...[
                      const Divider(height: 28, indent: 18, endIndent: 18, color: Colors.orange),
                      _drawerLienDirect(
                        icone: Icons.rocket_launch_outlined,
                        titre: '🚀 Simuler une Vraie Alerte',
                        onTap: _simulerVraieAlerteCourse,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _orKelegance.withOpacity(0.25), width: 0.6)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _orKelegance.withOpacity(0.65), width: 0.7),
                          foregroundColor: _orKelegance,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: _basculerModeClient,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Passer en mode Client',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.15,
                                  color: _orKelegance,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      title: const Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w400),
                      ),
                      onTap: _deconnecterChauffeur,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _libelleEtapeCourse() {
    switch (_currentStep) {
      case 'EN_ROUTE':
        return 'EN ROUTE VERS LE CLIENT';
      case 'SUR_PLACE':
        return 'SUR PLACE — EN ATTENTE DU CLIENT';
      case 'EN_COURSE':
        return 'COURSE EN COURS';
      default:
        return 'COURSE ACTIVE';
    }
  }

  Color? _couleurFondBoutonEtapeCourse() {
    switch (_currentStep) {
      case 'EN_ROUTE':
        return Colors.green;
      case 'SUR_PLACE':
        return Colors.orange;
      case 'EN_COURSE':
        return Colors.red;
      default:
        return null;
    }
  }

  void _afficherSnackPasDeTelephone() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text('Numéro client indisponible — vérifiez la fiche mission.'),
      ),
    );
  }

  Widget _buildBoutonsCommunicationApproche() {
    final tel = _telephoneClientCourse;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.withOpacity(0.65), width: 0.8),
                foregroundColor: const Color(0xFF81C784),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                ),
              ),
              icon: const Icon(Icons.chat_rounded, size: 15),
              label: const Text('WhatsApp Pro', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              onPressed: () {
                if (tel == null || tel.isEmpty) {
                  _afficherSnackPasDeTelephone();
                  return;
                }
                unawaited(KeleganceCommunication.ouvrirWhatsApp(context, tel));
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: KeleganceThemePremium.or.withOpacity(0.55), width: 0.8),
                foregroundColor: KeleganceThemePremium.or,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
                ),
              ),
              icon: const Icon(Icons.phone_rounded, size: 15),
              label: const Text('Appel / SMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              onPressed: () {
                if (tel == null || tel.isEmpty) {
                  _afficherSnackPasDeTelephone();
                  return;
                }
                unawaited(KeleganceCommunication.ouvrirAppel(context, tel));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _boutonWorkflowCourse(String label, VoidCallback onPressed) {
    final fondEtape = _couleurFondBoutonEtapeCourse();
    final etapeColoree = fondEtape != null;
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: etapeColoree ? fondEtape!.withOpacity(0.9) : KeleganceThemePremium.or.withOpacity(0.55),
            width: etapeColoree ? 1.2 : 0.8,
          ),
          foregroundColor: etapeColoree ? KeleganceThemePremium.textePrincipal : KeleganceThemePremium.or,
          backgroundColor: etapeColoree ? fondEtape : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: etapeColoree ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 1.4,
            color: etapeColoree ? KeleganceThemePremium.textePrincipal : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBoutonsGuidageItineraire({required bool approche, required bool enCourse}) {
    return Row(
      children: [
        if (approche)
          Expanded(
            child: _boutonGuidageItineraire(
              label: 'EN DIRECTION',
              actif: _guidageInAppOuvert && !_guidageVersDestination,
              onPressed: () => _ouvrirGuidageInApp(versDestination: false),
            ),
          ),
        if (approche && enCourse) const SizedBox(width: 10),
        if (enCourse)
          Expanded(
            child: _boutonGuidageItineraire(
              label: 'EN ROUTE',
              actif: _guidageInAppOuvert && _guidageVersDestination,
              onPressed: () => _ouvrirGuidageInApp(versDestination: true),
            ),
          ),
      ],
    );
  }

  Widget _boutonGuidageItineraire({
    required String label,
    required bool actif,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: actif ? KeleganceThemePremium.or : KeleganceThemePremium.or.withOpacity(0.45),
            width: actif ? 1.2 : 0.8,
          ),
          foregroundColor: actif ? KeleganceConfig.noirProfond : KeleganceThemePremium.or,
          backgroundColor: actif ? KeleganceThemePremium.or : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: actif ? KeleganceConfig.noirProfond : KeleganceThemePremium.or,
          ),
        ),
      ),
    );
  }

  Widget _buildPanneauGuidageInApp() {
    final titre = _guidageVersDestination ? 'EN ROUTE · DESTINATION' : 'EN DIRECTION · CLIENT';

    return Positioned(
      left: 12,
      right: 12,
      bottom: _offsetBasPanneauGuidage() + (_courseChauffeurActive ? 8 : 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: KeleganceThemePremium.fond.withOpacity(0.97),
            borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium + 2),
            border: Border.all(color: KeleganceThemePremium.or.withOpacity(0.55), width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _guidageVersDestination ? Icons.route_rounded : Icons.near_me_rounded,
                    color: KeleganceThemePremium.or,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titre,
                      style: KeleganceThemePremium.libelleNet().copyWith(fontSize: 10, letterSpacing: 1.4),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Fermer l\'itinéraire',
                    onPressed: _fermerGuidageInApp,
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.65), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _guidageAdresseCible,
                style: KeleganceThemePremium.titreAlerte(size: 12).copyWith(
                  color: KeleganceThemePremium.textePrincipal,
                  fontWeight: FontWeight.w300,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              if (_guidageChargement)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: KeleganceThemePremium.or),
                    ),
                    SizedBox(width: 10),
                    Text('Calcul de l\'itinéraire…', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                )
              else if (_guidageResume.isNotEmpty)
                Text(
                  _guidageResume,
                  style: const TextStyle(color: KeleganceThemePremium.or, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              if (_ecran != _EcranChauffeur.accueil) ...[
                const SizedBox(height: 8),
                Text(
                  'Tracé visible sur l\'onglet Accueil.',
                  style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 9, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdresseCourseCliquable({
    required String adresse,
    required VoidCallback onTap,
  }) {
    final texte = adresse.isNotEmpty ? adresse : 'Adresse non renseignée';
    final style = KeleganceThemePremium.titreAlerte(size: 13).copyWith(
      color: KeleganceThemePremium.or,
      fontWeight: FontWeight.w400,
      height: 1.35,
      decoration: TextDecoration.underline,
      decorationColor: KeleganceThemePremium.or.withOpacity(0.45),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: adresse.isNotEmpty ? onTap : null,
        borderRadius: BorderRadius.circular(KeleganceConfig.rayonBoutonPremium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(Icons.navigation_rounded, color: KeleganceThemePremium.or.withOpacity(0.9), size: 20),
              ),
              Expanded(
                child: Text(texte, style: style),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanneauCourseInferieur() {
    final client = _activeCourseData!['client']?.toString() ?? '';
    final depart = _activeCourseData!['depart']?.toString() ?? '';
    final destination = _activeCourseData!['destination']?.toString() ?? '';
    final enCourse = _currentStep == 'EN_COURSE';
    final approche = _currentStep == 'EN_ROUTE' || _currentStep == 'SUR_PLACE';
    final adresseCourante = enCourse ? destination : depart;

    Widget boutonEtape;
    switch (_currentStep) {
      case 'EN_ROUTE':
        boutonEtape = _boutonWorkflowCourse(
          'SUR PLACE',
          () => unawaited(_passerSurPlaceManuel()),
        );
        break;
      case 'SUR_PLACE':
        boutonEtape = _boutonWorkflowCourse('CLIENT À BORD', () => unawaited(_clientABord()));
        break;
      case 'EN_COURSE':
        boutonEtape = _boutonWorkflowCourse(
          'TERMINER LA COURSE',
          () => unawaited(_terminerCourse()),
        );
        break;
      default:
        boutonEtape = const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                KeleganceThemePremium.fond.withOpacity(0.97),
                KeleganceConfig.noirProfond.withOpacity(0.98),
              ],
            ),
            border: Border(top: BorderSide(color: KeleganceThemePremium.or.withOpacity(0.55), width: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _libelleEtapeCourse(),
                style: KeleganceThemePremium.libelleNet().copyWith(fontSize: 9, letterSpacing: 1.6),
              ),
              const SizedBox(height: 8),
              if (client.isNotEmpty)
                Text(
                  client,
                  style: KeleganceThemePremium.titreAlerte(size: 13).copyWith(
                    color: KeleganceThemePremium.or,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              if (client.isNotEmpty) const SizedBox(height: 6),
              if (approche || enCourse)
                _buildAdresseCourseCliquable(
                  adresse: adresseCourante,
                  onTap: _declencherGpsExternePourEtapeCourante,
                ),
              const SizedBox(height: 14),
              if (_currentStep == 'EN_ROUTE' || _currentStep == 'SUR_PLACE') ...[
                _buildBoutonsCommunicationApproche(),
                const SizedBox(height: 10),
              ],
              boutonEtape,
            ],
          ),
        ),
      ),
    );
  }

  void _fermerSOS() {
    if (!_sosAffiche) return;
    setState(() => _sosAffiche = false);
  }

  void _ouvrirSOSOverlay() {
    if (_sosAffiche) return;
    setState(() => _sosAffiche = true);
  }

  Widget _buildOverlaySOS() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.78),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text(
                        'URGENCE - SOS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sélectionnez le service d\'urgence à contacter immédiatement :',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  _buildSOSButton('SAMU (15)', Colors.red, _fermerSOS),
                  const SizedBox(height: 8),
                  _buildSOSButton('POLICE (17)', Colors.blue, _fermerSOS),
                  const SizedBox(height: 8),
                  _buildSOSButton('POMPIERS (18)', Colors.orange, _fermerSOS),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _fermerSOS,
                    child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    _ouvrirSOSOverlay();
  }

  Widget _buildSOSButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showReglementaireModal(BuildContext context, Map<String, dynamic> data, {String? docId}) {
    if (_modaleConsoleBloquante) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Fermez l\'alerte ou le SOS avant d\'ouvrir le bon de commande.'),
        ),
      );
      return;
    }
    final dateText = data['date'] ?? 'Date inconnue';
    final heureText = data['heure'] ?? '';
    final depart = data['depart'] ?? 'Non spécifié';
    final destination = data['destination'] ?? 'Non spécifiée';
    final clientEmail = data['client'] ?? 'Client inconnu';
    final typeMission = data['type'] ?? 'ALLER SIMPLE';
    final prixText = data['prix'] != null ? '${data['prix']} €' : 'Tarif forfaitaire';
    final estBonRetour = typeMission == 'BON DE COMMANDE RETOUR';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.amber, width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.gavel, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  estBonRetour ? 'BON DE COMMANDE RETOUR' : 'BON DE COMMANDE VTC',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DOCUMENT DE CONFORMITÉ RÉGLEMENTAIRE\n(Article L. 3122-9 du Code des transports)',
                  style: TextStyle(color: Colors.white60, fontSize: 10, fontStyle: FontStyle.italic),
                ),
                const Divider(color: Colors.amber, height: 20),
                _buildModalRow('Exploitant :', 'KELEGANCE PRESTIGE'),
                _buildModalRow('Client :', clientEmail),
                _buildModalRow('Date de prise en charge :', dateText),
                _buildModalRow('Heure de récupération :', heureText),
                _buildModalRow('Lieu de prise en charge :', depart),
                _buildModalRow('Destination :', destination),
                _buildModalRow('Prestation :', 'Transport Public Particulier de Personnes'),
                _buildModalRow('Tarif :', prixText),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _orKelegance.withOpacity(0.25)),
                  ),
                  child: Text(
                    estBonRetour
                        ? 'Le bon de commande a été envoyé automatiquement par e-mail à la réservation. La facture partira à la fin de la course.'
                        : 'Le bon de commande a été envoyé automatiquement par e-mail à la réservation. La facture partira à la fin de la course.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final document = estBonRetour
                      ? await KeleganceDocumentsClient.genererBonCommandeRetour(data, missionId: docId)
                      : await KeleganceDocumentsClient.publier(
                          type: 'BON DE COMMANDE VTC',
                          missionData: data,
                          missionId: docId,
                        );
                  final tel = await KeleganceCommunication.resoudreNumeroClient(data);
                  if (!mounted) return;
                  await KeleganceDocumentsClient.afficherFeuillePartage(
                    context,
                    document: document,
                    telephone: tel,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange,
                      content: Text('Erreur génération document : $e'),
                    ),
                  );
                }
              },
              child: const Text('Partager manuellement', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Clôture Firestore en arrière-plan — déclenche onMissionTerminee (facture auto).
  Future<void> _cloturerMissionEnArrierePlan(String docId, Map<String, dynamic> data) async {
    try {
      if (KeleganceStripePaiement.estStripe(data)) {
        final prix = (data['prix'] as num?)?.toDouble() ?? 0.0;
        if (prix > 0) {
          await FirebaseFirestore.instance.collection('missions').doc(docId).update({
            'paiementStatut': 'debite_test_stripe',
            'paiementLabel': KeleganceStripePaiement.libelleTicket,
          });
        }
      }

      await FirebaseFirestore.instance.collection('missions').doc(docId).update({
        'statut': 'TERMINÉ',
        'factureGeneree': false,
        'factureErreur': FieldValue.delete(),
        'pipeline_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance clôture mission arrière-plan: $e');
    }
  }

  Widget _lbl(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildModalRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _carteMissionChauffeur({
    required String docId,
    required Map<String, dynamic> data,
    required bool historique,
  }) {
    final dateText = data['date'] ?? 'Date inconnue';
    final heureText = (data['heure']?.toString() ?? '').trim();
    final heureAffichee = heureText.isNotEmpty ? heureText : '—:—';
    final itineraire = KeleganceGestionReservations.formaterItineraire(data);
    final statut = data['statut'] ?? 'EN ATTENTE';
    final clientEmail = data['client'] ?? 'Client inconnu';
    final typeMission = data['type'] ?? 'ALLER';
    final courseVerrouillee = _chauffeurOccupe;
    final demarrageBloque = _demarrageCourseBloque;

    Color statutColor = Colors.amber;
    if (statut == 'PLANIFIÉ') {
      statutColor = Colors.green;
    } else if (statut == 'TERMINÉ') {
      statutColor = Colors.grey;
    } else if (statut == 'EN_ROUTE' || statut == 'EN COURSE' || statut == 'SUR PLACE') {
      statutColor = Colors.blue;
    } else if (statut == 'ANNULÉ') {
      statutColor = Colors.redAccent;
    }

    if (!historique && _activeCourseId == docId) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: historique ? const Color(0xFF0A0A0A) : const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: historique ? _orKelegance.withOpacity(0.18) : _orKelegance.withOpacity(0.42),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (typeMission == 'BON DE COMMANDE RETOUR') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_return, color: Colors.amber, size: 14),
                    SizedBox(width: 6),
                    Text('BON DE COMMANDE RETOUR', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HEURE DE DÉPART',
                        style: TextStyle(color: Colors.white, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        heureAffichee,
                        style: const TextStyle(
                          color: _orKelegance,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateText,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statut, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  backgroundColor: statutColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => MissionDetailsScreen.ouvrir(
                context,
                docId: docId,
                data: data,
                couleurAccent: _orKelegance,
                fond: _noirProfond,
                onDemarrerCourse: () => _prendreCourse(docId, data),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      itineraire,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w400),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _orKelegance.withOpacity(0.7), size: 22),
                ],
              ),
            ),
            if (data['note']?.toString().trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Note : ${data['note']}',
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text('Client : $clientEmail', style: const TextStyle(color: _orKelegance, fontSize: 11, fontWeight: FontWeight.w400)),
            if (!historique) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white12, height: 1),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 5,
                children: [
                  KeleganceGestionReservations.barreActions(
                    context: context,
                    docId: docId,
                    data: data,
                    bloque: courseVerrouillee,
                    accesComplet: _accesComplet,
                    fontSize: 10,
                  ),
                  TextButton.icon(
                    onPressed: () => _showReglementaireModal(context, data, docId: docId),
                    icon: const Icon(Icons.gavel, color: Colors.amber, size: 15),
                    label: const Text('Voir le Bon', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: demarrageBloque ? Colors.grey.shade800 : Colors.amber,
                    foregroundColor: demarrageBloque ? Colors.white38 : Colors.black,
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: demarrageBloque ? null : () => _prendreCourse(docId, data),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('PRENDRE LA COURSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              if (demarrageBloque)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    !_isOnline
                        ? 'Veuillez passer En Ligne pour commencer cette course.'
                        : 'Course en cours — terminez la mission active avant d\'en prendre une autre.',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListeMissionsAgenda(
    List<QueryDocumentSnapshot> docs, {
    required bool historique,
    required ScrollController scrollController,
  }) {
    if (docs.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        key: PageStorageKey<String>(historique ? 'agenda_historique_vide' : 'agenda_actives_vide'),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(historique ? 0.45 : 0.6),
              borderRadius: BorderRadius.circular(12),
              border: historique ? null : Border.all(color: _orKelegance.withOpacity(0.2)),
            ),
            child: Text(
              historique
                  ? 'Aucune course terminée ou annulée.'
                  : 'Aucune course active pour le moment.',
              style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      key: PageStorageKey<String>(historique ? 'agenda_historique' : 'agenda_actives'),
      padding: const EdgeInsets.all(20),
      children: docs
          .map((doc) => _carteMissionChauffeur(
                docId: doc.id,
                data: doc.data() as Map<String, dynamic>,
                historique: historique,
              ))
          .toList(),
    );
  }

  String? _titreEcranChauffeur() {
    switch (_ecran) {
      case _EcranChauffeur.accueil:
        return null;
      case _EcranChauffeur.suiviHistorique:
        return 'Suivi & Historique';
      case _EcranChauffeur.revenus:
        return 'Revenus Net Chauffeur';
      case _EcranChauffeur.reservations:
        return 'Réservations';
      case _EcranChauffeur.profil:
        return 'Mon Profil';
      case _EcranChauffeur.parametres:
        return "Paramètres";
      case _EcranChauffeur.revenusFactures:
        return 'Revenus & Factures';
      case _EcranChauffeur.bonsRetour:
        return 'Bons de commande retour';
    }
  }

  int _indexEcranChauffeur() {
    switch (_ecran) {
      case _EcranChauffeur.accueil:
        return 0;
      case _EcranChauffeur.suiviHistorique:
        return 1;
      case _EcranChauffeur.revenus:
        return 2;
      case _EcranChauffeur.reservations:
        return 3;
      case _EcranChauffeur.profil:
        return 4;
      case _EcranChauffeur.parametres:
        return 5;
      case _EcranChauffeur.revenusFactures:
        return 6;
      case _EcranChauffeur.bonsRetour:
        return 7;
    }
  }

  int _indexCorpsChauffeur() {
    if (_courseChauffeurActive) return 0;
    return _indexEcranChauffeur();
  }

  Widget _buildCorpsChauffeur() {
    return IndexedStack(
      index: _indexCorpsChauffeur(),
      sizing: StackFit.expand,
      children: [
        _buildHomeView(),
        _buildSuiviHistoriqueJournalier(),
        _buildEcranRevenus(),
        _buildChauffeurConsoleAgenda(),
        _buildEcranProfilChauffeur(),
        _buildEcranParametresApp(),
        _buildEcranRevenusFacturesBrasDroit(),
        _buildEcranBonsRetourBrasDroit(),
      ],
    );
  }

  Widget _buildEcranBonsRetourBrasDroit() {
    if (!_accesComplet) {
      return Center(
        child: Text(
          'Accès réservé aux Bras Droit.',
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
        ),
      );
    }

    return ColoredBox(
      color: _noirProfond,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _orKelegance,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => KeleganceBonCommandeForm.afficher(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('+ Bon de commande retour', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: const [
                KeleganceListeBonsCommandeRetour(
                  modeExpert: true,
                  titre: 'HISTORIQUE GLOBAL — BONS DE COMMANDE RETOUR',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcranRevenusFacturesBrasDroit() {
    if (!_accesComplet) {
      return Center(
        child: Text(
          'Accès réservé aux Bras Droit.',
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
        ),
      );
    }

    return KeleganceFacturesStreamBuilder(
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        if (!snapshot.accesComplet) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Flux expert indisponible — reconnectez-vous avec un profil Bras Droit.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
              ),
            ),
          );
        }

        final docs = KeleganceFacturesService.trierParDateRecente(snapshot.docs);
        final totaux = KeleganceFacturesService.calculerTotauxDashboard(docs);

        return ColoredBox(
          color: _noirProfond,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              if (live)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Activité financière synchronisée',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, letterSpacing: 0.5),
                  ),
                ),
              Text(
                'VUE EXPERT — TOUTE L\'ACTIVITÉ',
                style: TextStyle(
                  color: _orKelegance.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              _buildBandeauTotauxFacturesBrasDroit(
                totalPaye: totaux.totalPaye,
                totalEnAttente: totaux.totalEnAttente,
                nbPayees: totaux.nbPayees,
                nbEnAttente: totaux.nbEnAttente,
                nbTotal: docs.length,
              ),
              const SizedBox(height: 22),
              Text(
                '${docs.length} facture(s)',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _orKelegance.withOpacity(0.22)),
                  ),
                  child: const Text(
                    'Aucune facture enregistrée pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildCarteFactureBrasDroit(
                    data: data,
                    miseAJourLive: live,
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBandeauTotauxFacturesBrasDroit({
    required double totalPaye,
    required double totalEnAttente,
    required int nbPayees,
    required int nbEnAttente,
    required int nbTotal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _orKelegance.withOpacity(0.14),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orKelegance.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTuileTotalFacture(
                  label: 'Total payé',
                  montant: totalPaye,
                  sousTitre: '$nbPayees facture(s)',
                  couleur: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTuileTotalFacture(
                  label: 'En attente',
                  montant: totalEnAttente,
                  sousTitre: '$nbEnAttente facture(s)',
                  couleur: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Encours global : ${(totalPaye + totalEnAttente).toStringAsFixed(2)} € · $nbTotal document(s)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildTuileTotalFacture({
    required String label,
    required double montant,
    required String sousTitre,
    required Color couleur,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: couleur.withOpacity(0.9), fontSize: 10, letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Text(
            '${montant.toStringAsFixed(2)} €',
            style: TextStyle(color: couleur, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(sousTitre, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildCarteFactureBrasDroit({
    required Map<String, dynamic> data,
    bool miseAJourLive = false,
  }) {
    final numero = data['numero']?.toString() ?? 'Facture';
    final client = data['client']?.toString() ?? data['email']?.toString() ?? 'Client';
    final dateText = data['date']?.toString() ?? '—';
    final montant = KeleganceFacturesService.parserMontant(data['montant']);
    final statut = KeleganceFacturesService.presenterStatut(data['statut']?.toString());
    final lienWeb = data['lienWeb']?.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: miseAJourLive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.08), blurRadius: 8)],
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _orKelegance.withOpacity(0.22)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFFD4AF37)),
          title: Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(client, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
              Text(dateText, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statut.couleur.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statut.libelle,
                  style: TextStyle(color: statut.couleur, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${montant.toStringAsFixed(2)} €',
                style: const TextStyle(color: _orKelegance, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (lienWeb != null && lienWeb.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Partager',
                      icon: Icon(Icons.ios_share_rounded, color: _orKelegance.withOpacity(0.85), size: 18),
                      onPressed: () => unawaited(
                        KeleganceDocumentsClient.partagerLien(
                          context,
                          KeleganceDocumentsClient.depuisFacture(data),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Envoyer par e-mail',
                      icon: Icon(Icons.email_outlined, color: _orKelegance.withOpacity(0.85), size: 18),
                      onPressed: () => unawaited(
                        KeleganceDocumentsClient.envoyerLienParEmail(
                          context,
                          KeleganceDocumentsClient.depuisFacture(data),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          onTap: lienWeb != null && lienWeb.isNotEmpty
              ? () => unawaited(launchUrl(Uri.parse(lienWeb), mode: LaunchMode.externalApplication))
              : null,
        ),
      ),
    );
  }

  Widget _buildEcranProfilChauffeur() {
    return ColoredBox(
      color: _noirProfond,
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollProfil,
          physics: const ClampingScrollPhysics(),
          key: const PageStorageKey<String>('profil_chauffeur'),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MON PROFIL CHAUFFEUR',
                textAlign: TextAlign.center,
                style: TextStyle(color: _orKelegance, fontWeight: FontWeight.w500, fontSize: 16, letterSpacing: 1.2),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _orKelegance.withOpacity(0.12),
                      child: const Icon(Icons.person_outline, color: _orKelegance, size: 38),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _nomProfilChauffeur,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Partenaire Kelegance Prestige',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 14),
                    _ligneProfil(Icons.directions_car_outlined, 'Véhicule', 'Véhicule Premium Kelegance'),
                    const SizedBox(height: 12),
                    _ligneProfil(Icons.verified_outlined, 'Statut', _isOnline ? 'En ligne' : 'Hors ligne'),
                    const SizedBox(height: 12),
                    _ligneProfil(Icons.email_outlined, 'E-mail', FirebaseAuth.instance.currentUser?.email ?? '—'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEcranParametresApp() {
    return ColoredBox(
      color: _noirProfond,
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollParametres,
          physics: const ClampingScrollPhysics(),
          key: const PageStorageKey<String>('parametres_chauffeur'),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "PARAMÈTRES DE L'APPLI",
                      style: TextStyle(color: _orKelegance, fontWeight: FontWeight.w500, fontSize: 16, letterSpacing: 1.2),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded, color: _orKelegance, size: 22),
                    onPressed: _retourAccueilChauffeur,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Configuration console chauffeur',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Ouverture automatique de la navigation',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Lance Google Maps au démarrage de la course (vers le client, puis vers la destination)',
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
                      ),
                      value: _gpsAutomatique,
                      activeColor: _orKelegance,
                      onChanged: (v) => setState(() => _gpsAutomatique = v),
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Statut automatique', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text(
                        'Passe en « Sur place » quand vous êtes à moins de 180 m du client',
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
                      ),
                      value: _statutAutomatique,
                      activeColor: _orKelegance,
                      onChanged: (v) => setState(() => _statutAutomatique = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.22)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.notifications_active_outlined, color: _orKelegance.withOpacity(0.9)),
                  title: const Text(
                    'Préférences de notifications',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Missions assignées, rappels 1 h avant départ, factures payées',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: _orKelegance.withOpacity(0.75)),
                  onTap: _ouvrirPreferencesNotifications,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Volume alerte course', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    Slider(
                      value: _volumeAlerte,
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      activeColor: _orKelegance,
                      inactiveColor: Colors.white24,
                      label: '${(_volumeAlerte * 100).round()} %',
                      onChanged: (v) {
                        setState(() => _volumeAlerte = v);
                        KeleganceAudioAlertes.definirVolumeAlerte(v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Application GPS', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in [
                          KeleganceConsolePrefs.gpsGoogleMaps,
                          KeleganceConsolePrefs.gpsWaze,
                          if (keleganceEstIOS) KeleganceConsolePrefs.gpsAppleMaps,
                        ])
                          ChoiceChip(
                            label: Text(option, style: const TextStyle(fontSize: 11)),
                            selected: _gpsDefaut == option,
                            selectedColor: _orKelegance,
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(
                              color: _gpsDefaut == option ? Colors.black : Colors.white70,
                            ),
                            onSelected: (_) => setState(() => _gpsDefaut = option),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (_accesComplet)
                const KeleganceBoutonQrAdmin()
              else
                const KeleganceBoutonQrChauffeur(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      KeleganceOtaUpdate.disponible ? 'Mise à jour automatique (OTA)' : 'Mise à jour de l\'application',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      KeleganceOtaUpdate.disponible
                          ? 'Télécharge et installe la dernière version sans brancher le téléphone.'
                          : 'Vérifiez et rechargez les dernières ressources (PWA / web).',
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _orKelegance.withOpacity(0.55)),
                        foregroundColor: _orKelegance,
                      ),
                      onPressed: () => unawaited(KeleganceOtaUpdate.verifierMiseAJourUniverselle(context)),
                      icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                      label: const Text('Vérifier les mises à jour', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const KeleganceRolesDiagnostic(),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () async {
                  await _sauvegarderPreferencesConsole();
                  if (!mounted) return;
                  _retourAccueilChauffeur();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _orKelegance,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneProfil(IconData icone, String label, String valeur) {
    return Row(
      children: [
        Icon(icone, color: _orKelegance.withOpacity(0.75), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(valeur, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _enrichirMissionChauffeur(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    String? tel;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        tel = doc.data()?['phone']?.toString().trim();
      } catch (_) {}
    }
    await FirebaseFirestore.instance.collection('missions').doc(docId).update({
      'chauffeurNom': 'Nicolas',
      'chauffeurVehicule': 'Véhicule Premium Kelegance',
      if (tel != null && tel.isNotEmpty) 'chauffeurTel': tel,
    });
  }

  Widget _buildSuiviHistoriqueJournalier() {
    return KeleganceMissionsStreamBuilder(
      builder: (context, snapshot, _) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = snapshot.docs;
        final aujourdhui = <Map<String, dynamic>>[];

        final email = FirebaseAuth.instance.currentUser?.email;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (!KeleganceRoles.peutVoirMission(data, email: email)) continue;
          final statut = (data['statut']?.toString() ?? '').toUpperCase().replaceAll('É', 'E').trim();
          if (statut != 'TERMINE' && statut != 'TERMINÉ') continue;
          final dateCloture = _dateClotureCourse(data);
          if (dateCloture == null || !_estAujourdhui(dateCloture)) continue;
          aujourdhui.add({...data, 'id': doc.id});
        }

        final demos = _accesBrasDroit ? KeleganceHistoriqueDemo.coursesTestAujourdhui() : <Map<String, dynamic>>[];
        final fusion = <Map<String, dynamic>>[...demos, ...aujourdhui];
        fusion.sort((a, b) {
          final da = KeleganceMissionTri.extraireHorodatage(a);
          final db = KeleganceMissionTri.extraireHorodatage(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });

        final totalNet = fusion.fold<double>(0, (sum, m) {
          final prix = (m['prix'] as num?)?.toDouble() ?? 0;
          return sum + KeleganceCommission.ventiler(prix).netChauffeur;
        });

        return ColoredBox(
          color: _noirProfond,
          child: ListView(
            controller: _scrollHistorique,
            physics: const ClampingScrollPhysics(),
            key: const PageStorageKey<String>('suivi_historique'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              const Text(
                'SUIVI & HISTORIQUE',
                style: TextStyle(color: _orKelegance, fontWeight: FontWeight.w500, fontSize: 15, letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                'Journalier · ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
              ),
              const SizedBox(height: 18),
              KeleganceThemePremium.bandeauNetChauffeur(
                netText: totalNet.toStringAsFixed(2),
                prixText: fusion.fold<double>(0, (s, m) => s + ((m['prix'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2),
              ),
              const SizedBox(height: 22),
              Text(
                '${fusion.length} course(s) aujourd\'hui',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 12),
              if (fusion.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _orKelegance.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'Aucune course terminée aujourd\'hui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...fusion.map(_buildCarteHistoriqueJournaliere),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarteHistoriqueJournaliere(Map<String, dynamic> data) {
    final heure = data['heure']?.toString() ?? '—:—';
    final depart = data['depart']?.toString() ?? '—';
    final destination = data['destination']?.toString() ?? '—';
    final client = data['client']?.toString() ?? 'Client';
    final libelle = data['libelleTarif']?.toString() ?? '';
    final prix = (data['prix'] as num?)?.toDouble() ?? 0;
    final net = KeleganceCommission.ventiler(prix).netChauffeur;
    final estDemo = data['demo'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orKelegance.withOpacity(estDemo ? 0.28 : 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(heure, style: const TextStyle(color: _orKelegance, fontSize: 26, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (estDemo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('TEST', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text('$depart ➔ $destination', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
          const SizedBox(height: 6),
          Text('Client : $client', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
          if (libelle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(libelle, style: TextStyle(color: _orKelegance.withOpacity(0.8), fontSize: 10)),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NET CHAUFFEUR', style: KeleganceThemePremium.libelleNet().copyWith(fontSize: 9)),
                  Text('${net.toStringAsFixed(2)} €', style: KeleganceThemePremium.montantNet(size: 22)),
                ],
              ),
              Text('TTC ${prix.toStringAsFixed(2)} €', style: KeleganceThemePremium.montantTtc()),
            ],
          ),
        ],
      ),
    );
  }

  List<DateTime> _joursPeriodeRevenus() {
    final ref = DateTime(_jourRevenuSelectionne.year, _jourRevenuSelectionne.month, _jourRevenuSelectionne.day);
    if (_periodeRevenu == _PeriodeRevenu.mois) {
      final debut = DateTime(ref.year, ref.month, 1);
      final fin = DateTime(ref.year, ref.month + 1, 0);
      final jours = <DateTime>[];
      for (var d = debut; !d.isAfter(fin); d = d.add(const Duration(days: 1))) {
        jours.add(d);
      }
      return jours;
    }
    final lundi = ref.subtract(Duration(days: ref.weekday - 1));
    return List.generate(7, (i) => lundi.add(Duration(days: i)));
  }

  String _libellePeriodeRevenus() {
    final jours = _joursPeriodeRevenus();
    if (_periodeRevenu == _PeriodeRevenu.mois) {
      const mois = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
      return '${mois[jours.first.month]} ${jours.first.year}';
    }
    final debut = jours.first;
    final fin = jours.last;
    return '${debut.day}/${debut.month} — ${fin.day}/${fin.month}/${fin.year}';
  }

  Widget _buildBarreRevenuJour({
    required DateTime jour,
    required double net,
    required double maxJour,
    required bool mensuel,
  }) {
    const hauteurZoneBarres = 72.0;
    final hauteur = maxJour > 0 ? (net / maxJour) * hauteurZoneBarres : 4.0;
    final labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final label = mensuel ? '${jour.day}' : labels[jour.weekday - 1];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (net > 0)
          Text(
            net.toStringAsFixed(0),
            style: TextStyle(color: _orKelegance.withOpacity(0.85), fontSize: 7, height: 1),
          ),
        const SizedBox(height: 3),
        Container(
          height: hauteur.clamp(3, hauteurZoneBarres),
          decoration: BoxDecoration(
            color: net > 0 ? _orKelegance.withOpacity(0.85) : Colors.white12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 8, height: 1)),
      ],
    );
  }

  Widget _buildGraphiqueRevenus({
    required List<DateTime> jours,
    required Map<String, double> parJour,
    required double maxJour,
  }) {
    final mensuel = _periodeRevenu == _PeriodeRevenu.mois;
    const hauteurGraphique = 96.0;

    final barres = jours.map((jour) {
      final cle = '${jour.year}-${jour.month}-${jour.day}';
      final net = parJour[cle] ?? 0;
      return _buildBarreRevenuJour(jour: jour, net: net, maxJour: maxJour, mensuel: mensuel);
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orKelegance.withOpacity(0.22)),
      ),
      child: mensuel
          ? SingleChildScrollView(
              controller: _scrollGraphiqueRevenus,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: hauteurGraphique,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(barres.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: SizedBox(width: 20, child: barres[i]),
                    );
                  }),
                ),
              ),
            )
          : SizedBox(
              height: hauteurGraphique,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(barres.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: barres[i],
                    ),
                  );
                }),
              ),
            ),
    );
  }

  Widget _buildEcranRevenus() {
    return KeleganceMissionsStreamBuilder(
      builder: (context, snapshot, _) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final jours = _joursPeriodeRevenus();
        final debut = jours.first;
        final fin = jours.last;
        final parJour = <String, double>{};
        for (final j in jours) {
          parJour['${j.year}-${j.month}-${j.day}'] = 0;
        }

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final statut = (data['statut']?.toString() ?? '').toUpperCase().replaceAll('É', 'E').trim();
          if (statut != 'TERMINE' && statut != 'TERMINÉ') continue;
          final dateCloture = _dateClotureCourse(data);
          if (dateCloture == null) continue;
          final cle = '${dateCloture.year}-${dateCloture.month}-${dateCloture.day}';
          if (!parJour.containsKey(cle)) continue;
          final prix = (data['prix'] as num?)?.toDouble() ?? 0;
          parJour[cle] = (parJour[cle] ?? 0) + KeleganceCommission.ventiler(prix).netChauffeur;
        }

        for (final demo in KeleganceHistoriqueDemo.coursesTestAujourdhui()) {
          final dateDemo = KeleganceMissionTri.extraireHorodatage(demo);
          if (dateDemo == null) continue;
          if (dateDemo.isBefore(debut) || dateDemo.isAfter(fin.add(const Duration(hours: 23, minutes: 59)))) continue;
          final cle = '${dateDemo.year}-${dateDemo.month}-${dateDemo.day}';
          if (!parJour.containsKey(cle)) continue;
          final prix = (demo['prix'] as num?)?.toDouble() ?? 0;
          parJour[cle] = (parJour[cle] ?? 0) + KeleganceCommission.ventiler(prix).netChauffeur;
        }

        final totalNet = parJour.values.fold<double>(0, (a, b) => a + b);
        final maxJour = parJour.values.fold<double>(0, (a, b) => a > b ? a : b);

        return ColoredBox(
          color: _noirProfond,
          child: ListView(
            controller: _scrollRevenus,
            physics: const ClampingScrollPhysics(),
            key: const PageStorageKey<String>('revenus_chauffeur'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              const Text(
                'REVENUS NET CHAUFFEUR',
                style: TextStyle(color: _orKelegance, fontWeight: FontWeight.w500, fontSize: 15, letterSpacing: 1.4),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_PeriodeRevenu>(
                segments: const [
                  ButtonSegment(value: _PeriodeRevenu.semaine, label: Text('Hebdo', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: _PeriodeRevenu.mois, label: Text('Mensuel', style: TextStyle(fontSize: 11))),
                ],
                selected: {_periodeRevenu},
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white70,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? _orKelegance : Colors.white10,
                  ),
                ),
                onSelectionChanged: (sel) => setState(() => _periodeRevenu = sel.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: _orKelegance),
                    onPressed: () {
                      setState(() {
                        _jourRevenuSelectionne = _periodeRevenu == _PeriodeRevenu.mois
                            ? DateTime(_jourRevenuSelectionne.year, _jourRevenuSelectionne.month - 1, 1)
                            : _jourRevenuSelectionne.subtract(const Duration(days: 7));
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      _libellePeriodeRevenus(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: _orKelegance),
                    onPressed: () {
                      setState(() {
                        _jourRevenuSelectionne = _periodeRevenu == _PeriodeRevenu.mois
                            ? DateTime(_jourRevenuSelectionne.year, _jourRevenuSelectionne.month + 1, 1)
                            : _jourRevenuSelectionne.add(const Duration(days: 7));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              KeleganceThemePremium.bandeauNetChauffeur(
                netText: totalNet.toStringAsFixed(2),
                prixText: (totalNet / KeleganceCommission.tauxNetChauffeur).toStringAsFixed(2),
              ),
              const SizedBox(height: 20),
              _buildGraphiqueRevenus(jours: jours, parJour: parJour, maxJour: maxJour),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChauffeurConsoleAgenda() {
    return KeleganceMissionsStreamBuilder(
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = KeleganceMissionTri.trierChronologique(snapshot.docs);
        final email = FirebaseAuth.instance.currentUser?.email;
        final docsFiltres = _accesBrasDroit
            ? docs
            : docs
                .where((doc) => KeleganceRoles.peutVoirMission(doc.data() as Map<String, dynamic>, email: email))
                .toList();
        final missionsActives =
            docsFiltres.where((doc) => !_estMissionHistorique(doc.data() as Map<String, dynamic>)).toList();
        final missionsHistorique =
            docsFiltres.where((doc) => _estMissionHistorique(doc.data() as Map<String, dynamic>)).toList();
        missionsHistorique.sort((a, b) {
          final da = KeleganceMissionTri.extraireHorodatage(a.data() as Map<String, dynamic>);
          final db = KeleganceMissionTri.extraireHorodatage(b.data() as Map<String, dynamic>);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });

        return DefaultTabController(
          length: 2,
          child: Container(
            color: Colors.black.withOpacity(0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: _noirProfond,
                  child: TabBar(
                    indicatorColor: _orKelegance,
                    indicatorWeight: 2,
                    labelColor: _orKelegance,
                    unselectedLabelColor: Colors.white54,
                    dividerColor: _orKelegance.withOpacity(0.2),
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
                    unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
                    tabs: const [
                      Tab(text: 'Missions'),
                      Tab(text: 'Historique'),
                    ],
                  ),
                ),
                if (live)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Planning synchronisé',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _orKelegance.withOpacity(0.75), fontSize: 10, letterSpacing: 0.5),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListeMissionsAgenda(
                        missionsActives,
                        historique: false,
                        scrollController: _scrollAgendaActives,
                      ),
                      _buildListeMissionsAgenda(
                        missionsHistorique,
                        historique: true,
                        scrollController: _scrollAgendaHistorique,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_accesComplet)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 168),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: const KelegancePresenceEquipe(),
                  ),
                ),
              if (_accesComplet) const SizedBox(height: 6),
              _buildBandeauCaCentre(),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildCarte3DFond()),
              _buildBoutonRecentrerCarte(),
            ],
          ),
        ),
        ColoredBox(
          color: const Color(0xFF0A0A0A),
          child: SizedBox(
            height: _paddingMasquageBandeauGoogle,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildBoutonStatutChauffeurFixe() {
    return Material(
      color: _isOnline ? Colors.green : Colors.red,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          setState(() => _isOnline = !_isOnline);
          await _synchroniserPresenceFirestore();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isOnline ? 'Vous êtes maintenant EN LIGNE' : 'Vous êtes maintenant HORS LIGNE'),
              backgroundColor: _isOnline ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isOnline ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isOnline ? 'EN LIGNE' : 'HORS LIGNE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarreNavigationChauffeur() {
    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _naviguerVersEcran(_EcranChauffeur.accueil),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home, color: _ecran == _EcranChauffeur.accueil ? Colors.amber : Colors.white54, size: 22),
                    Text(
                      'Accueil',
                      style: TextStyle(
                        color: _ecran == _EcranChauffeur.accueil ? Colors.amber : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(child: _buildBoutonStatutChauffeurFixe()),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _naviguerVersEcran(_EcranChauffeur.reservations),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, color: _ecran == _EcranChauffeur.reservations ? Colors.amber : Colors.white54, size: 22),
                    Text(
                      'Réservations',
                      style: TextStyle(
                        color: _ecran == _EcranChauffeur.reservations ? Colors.amber : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navVisible = !_courseImmersive;

    return PopScope(
      canPop: _ecran == _EcranChauffeur.accueil,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_ecran != _EcranChauffeur.accueil) {
          _retourAccueilChauffeur();
        }
      },
      child: Scaffold(
      backgroundColor: _noirProfond,
      extendBodyBehindAppBar: _carteAccueilVisible,
      extendBody: false,

      drawer: _ecran == _EcranChauffeur.parametres ? null : _buildDrawerChauffeur(),

      appBar: AppBar(
        backgroundColor: _carteAccueilVisible ? Colors.transparent : _noirProfond,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: _ecran != _EcranChauffeur.parametres,
        leading: _ecran == _EcranChauffeur.parametres
            ? IconButton(
                tooltip: 'Retour à l\'accueil',
                icon: const Icon(Icons.close_rounded, color: _orKelegance, size: 22),
                onPressed: _retourAccueilChauffeur,
              )
            : null,
        iconTheme: const IconThemeData(color: _orKelegance, size: 22),
        title: _titreEcranChauffeur() == null
            ? const SizedBox.shrink()
            : Text(
                _titreEcranChauffeur()!,
                style: const TextStyle(color: _orKelegance, fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.6),
              ),
        centerTitle: true,
        actions: [
          if (_accesComplet)
            TextButton.icon(
              onPressed: () => KeleganceBonCommandeForm.afficher(context),
              icon: const Icon(Icons.assignment_return, color: _orKelegance, size: 18),
              label: const Text(
                '+ Bon de commande retour',
                style: TextStyle(color: _orKelegance, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: 'Réservation instantanée',
            icon: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _orKelegance.withOpacity(0.65), width: 0.7),
              ),
              child: const Icon(Icons.add, color: _orKelegance, size: 16),
            ),
            onPressed: _showReservationInstantanee,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.7), width: 0.8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'SOS',
                style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.5),
              ),
            ),
            onPressed: () => _showSOSDialog(context),
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCorpsChauffeur(),
          if (_courseChauffeurActive) _buildPanneauCourseInferieur(),
          if (_guidageInAppOuvert && !_courseChauffeurActive) _buildPanneauGuidageInApp(),
          if (_alerteCourseAffichee) _buildOverlayAlerteCourse(),
          if (_sosAffiche) _buildOverlaySOS(),
          if (_demarrageCourseEnCours)
            Container(
              color: Colors.black.withOpacity(0.45),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orKelegance.withOpacity(0.35)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: _orKelegance),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Démarrage de la course...',
                      style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: navVisible ? _buildBarreNavigationChauffeur() : null,
      ),
    );
  }
}