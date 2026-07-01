import 'kelegance_chauffeurs_referentiel.dart';
import 'kelegance_documents_pdf_service.dart';

/// Génération bon de commande — lookup chauffeur assigné (pas de données en dur).
abstract final class KeleganceBonCommandeGenerator {
  static const String erreurDonneesIncompletes = 'Données chauffeur incomplètes';

  /// Vérifie le profil chauffeur avant validation / publication BDC.
  static Future<KeleganceProfilChauffeurBdc> verifierChauffeurPourMission(
    Map<String, dynamic> mission,
  ) {
    return KeleganceChauffeursReferentiel.exigerDepuisMission(mission);
  }

  /// Construit les données document avec profil chauffeur résolu dynamiquement.
  static Future<KeleganceDocumentDonnees> preparerDonnees({
    required Map<String, dynamic> missionData,
    required String type,
    required String token,
    String? numeroDocument,
    String? missionId,
  }) async {
    final profil = await KeleganceChauffeursReferentiel.exigerDepuisMission(missionData);
    return KeleganceDocumentDonnees.depuisMission(
      missionData,
      type: type,
      token: token,
      numeroDocument: numeroDocument,
      missionId: missionId,
      profilChauffeur: profil,
    );
  }

  /// HTML bon de commande — échoue si chauffeur non référencé.
  static Future<String> genererHtmlBonCommande({
    required String type,
    required Map<String, dynamic> missionData,
    required String token,
    String? numeroDocument,
    String? missionId,
  }) async {
    final donnees = await preparerDonnees(
      missionData: missionData,
      type: type,
      token: token,
      numeroDocument: numeroDocument,
      missionId: missionId,
    );
    return KeleganceDocumentsPdfService.genererHtml(type: type, donnees: donnees);
  }
}
