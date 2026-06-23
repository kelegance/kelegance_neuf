import 'package:flutter/material.dart';

/// Question / réponse FAQ Kélégance.
class KeleganceFaq {
  final String question;
  final String reponse;

  const KeleganceFaq({required this.question, required this.reponse});
}

/// Fiche document chauffeur partenaire.
class KeleganceDocumentChauffeur {
  final String id;
  final String titre;
  final String instruction;
  final IconData icone;

  const KeleganceDocumentChauffeur({
    required this.id,
    required this.titre,
    required this.instruction,
    required this.icone,
  });
}

/// Contenus professionnels — FAQ, mentions légales, guides chauffeur (v2.2.1).
abstract final class KeleganceContenus {
  static const String contactSupport = 'contact@kelegance-prestige.com';

  static const List<KeleganceFaq> faqClient = [
    KeleganceFaq(
      question: 'Comment réserver une course ?',
      reponse:
          'Rendez-vous dans l\'onglet « Réserver », saisissez votre lieu de prise en charge et votre destination, '
          'sélectionnez la date, l\'heure et le nombre de passagers (1 à 4), puis validez avec le bouton '
          '« CONFIRMER LA RÉSERVATION ». Votre demande apparaît immédiatement dans l\'onglet « Agenda ». '
          'Vous recevez une confirmation dès que votre chauffeur Kélégance valide la mission.',
    ),
    KeleganceFaq(
      question: 'Comment fonctionne le tarif fixe ?',
      reponse:
          'Kélégance applique une politique de transparence totale : le tarif affiché avant validation '
          'est le tarif définitif de votre trajet (forfaits aéroports, gares ou course sur mesure). '
          'Aucun supplément caché, aucune surprise à l\'arrivée. Le montant convenu est inscrit sur votre '
          'bon de commande réglementaire et sur votre facture.',
    ),
    KeleganceFaq(
      question: 'Capacité des véhicules',
      reponse:
          'Nos prestations sont assurées en berline de prestige. La capacité maximale est strictement '
          'limitée à 4 passagers par véhicule, bagages cabine inclus selon disponibilité. '
          'Le sélecteur de l\'application est verrouillé à 4 passagers maximum pour garantir '
          'votre confort et la conformité de la mission.',
    ),
    KeleganceFaq(
      question: 'Prestations incluses',
      reponse:
          'Chaque course Kélégance inclut à bord : bouteilles d\'eau, chargeurs USB-C '
          'et Wi-Fi à bord (sur demande). Ces services sont offerts à tous les membres '
          'de notre cercle privé, sans supplément.',
    ),
  ];

  static const List<KeleganceFaq> faqChauffeur = [
    ...faqClient,
    KeleganceFaq(
      question: 'Comment passer EN LIGNE ?',
      reponse:
          'Activez le bouton « EN LIGNE » depuis l\'écran d\'accueil chauffeur. Votre statut est '
          'synchronisé en temps réel sur Firestore. Seul un chauffeur EN LIGNE peut accepter et '
          'piloter une course (Sur place, Client à bord, Terminer).',
    ),
    KeleganceFaq(
      question: 'Comment gérer une course en cours ?',
      reponse:
          'Après « PRENDRE LA COURSE », suivez le workflow : SUR PLACE → CLIENT À BORD → TERMINER. '
          'Le guidage GPS et le tracé s\'activent automatiquement au départ de la course. '
          'Le client est notifié à chaque étape.',
    ),
    KeleganceFaq(
      question: 'Documents obligatoires',
      reponse:
          'Accédez au menu « Documents obligatoires » pour consulter la liste des pièces à fournir '
          '(Carte VTC, assurance, Kbis). Téléversez des documents lisibles, en cours de validité. '
          'L\'équipe Kélégance valide votre dossier sous 48 h ouvrées.',
    ),
  ];

  static const String confidentialiteRgpd = '''
POLITIQUE DE CONFIDENTIALITÉ — KÉLÉGANCE PRESTIGE

Dernière mise à jour : __DATE__

1. RESPONSABLE DU TRAITEMENT
Kélégance Prestige, transport de personnes à titre onéreux (VTC), est responsable du traitement de vos données personnelles conformément au Règlement Général sur la Protection des Données (RGPD — UE 2016/679).

2. DONNÉES COLLECTÉES
• Identité et contact : nom, adresse e-mail, numéro de téléphone.
• Données de réservation : lieux de prise en charge et destinations, dates, horaires, nombre de passagers.
• Données de facturation : historique des courses et montants.

3. DONNÉES DE LOCALISATION GPS
Les coordonnées GPS du chauffeur sont collectées UNIQUEMENT pendant l'exécution active d'une course (statuts « En route », « Sur place », « En cours »), afin de :
• Permettre le suivi en temps réel de votre véhicule ;
• Assurer votre sécurité et la qualité de service ;
• Générer le tracé d'itinéraire affiché dans l'application.

En dehors d'une course active, aucune géolocalisation continue n'est exploitée à des fins commerciales. Les données GPS sont supprimées ou anonymisées conformément à nos durées de conservation.

4. FINALITÉS ET BASE LÉGALE
• Exécution du contrat de transport (art. 6.1.b RGPD).
• Obligations légales VTC (registre, bons de commande — art. 6.1.c).
• Intérêt légitime d'amélioration du service (art. 6.1.f).

5. VOS DROITS
Vous disposez d'un droit d'accès, de rectification, d'effacement, de limitation, de portabilité et d'opposition. Pour exercer vos droits : $contactSupport.

6. CONSERVATION
Les données de course sont conservées 5 ans (obligations comptables et réglementaires VTC). Les données GPS de navigation sont conservées 12 mois maximum.

7. SÉCURITÉ
Vos données sont hébergées sur l'infrastructure Google Firebase (UE / clauses contractuelles types). L'accès est restreint aux personnels habilités Kélégance.
''';

  static const String conditionsGeneralesVente = '''
CONDITIONS GÉNÉRALES DE VENTE — KÉLÉGANCE PRESTIGE
Transport de personnes à titre onéreux (VTC / Chauffeur privé)

Article 1 — Objet
Les présentes Conditions Générales de Vente (CGV) régissent les prestations de transport de personnes proposées par Kélégance Prestige auprès de sa clientèle privée, via l'application mobile Kélégance.

Article 2 — Accès au service
L'application est accessible sur invitation uniquement. L'ouverture de compte est subordonnée à la validation préalable par Kélégance (champ isApproved). Kélégance se réserve le droit de refuser ou de suspendre un compte en cas de non-respect des présentes CGV.

Article 3 — Réservation
Toute course fait l'objet d'une réservation préalable via l'application. Le client renseigne les adresses, la date, l'heure et le nombre de passagers. La réservation est confirmée après validation par Kélégance ou attribution d'un chauffeur. Un bon de commande réglementaire (article L. 3122-9 du Code des transports) est généré pour chaque prestation.

Article 4 — Tarifs et paiement
Les tarifs affichés dans l'application constituent des forfaits fermes ou des estimations validées avant le départ. Le prix convenu ne peut être modifié unilatéralement en cours de course, sauf demande de modification d'itinéraire acceptée par le client. Le paiement s'effectue selon les modalités communiquées par Kélégance (carte bancaire, virement, compte entreprise).

Article 5 — Annulation et modification
• Annulation par le client plus de 24 h avant la prise en charge : sans frais.
• Annulation entre 24 h et 2 h : 50 % du forfait pourra être facturé.
• Annulation moins de 2 h avant ou absence (no-show) : intégralité du forfait due.
Toute modification d'horaire ou de destination est soumise à disponibilité et peut entraîner un ajustement tarifaire communiqué avant validation.

Article 6 — Obligations du client
Le client s'engage à fournir des informations exactes, à respecter la capacité maximale de 4 passagers en berline, et à adopter un comportement respectueux envers le chauffeur et le véhicule. Il est interdit de fumer, de consommer de la nourriture ou d'introduire des animaux sans accord préalable.

Article 7 — Responsabilité
Kélégance est tenue à une obligation de moyens dans la mise en œuvre de la prestation. La responsabilité de Kélégance ne saurait être engagée en cas de force majeure, d'événements indépendants de sa volonté (trafic exceptionnel, conditions météorologiques) ou de retard imputable au client.

Article 8 — Réclamations
Toute réclamation doit être adressée sous 72 h suivant la course à : $contactSupport. Kélégance s'engage à répondre sous 5 jours ouvrés.

Article 9 — Droit applicable
Les présentes CGV sont soumises au droit français. Tout litige relève des tribunaux compétents du ressort du siège social de Kélégance Prestige.
''';

  static const List<KeleganceDocumentChauffeur> documentsChauffeur = [
    KeleganceDocumentChauffeur(
      id: 'carte_vtc',
      titre: 'Carte Professionnelle VTC',
      instruction: 'Veuillez téléverser votre Carte Professionnelle VTC (Recto/Verso). '
          'Le document doit être lisible, en cours de validité, au format PDF ou JPEG.',
      icone: Icons.badge_outlined,
    ),
    KeleganceDocumentChauffeur(
      id: 'assurance',
      titre: 'Assurance transport à titre onéreux',
      instruction: 'Veuillez téléverser votre attestation d\'assurance transport à titre onéreux '
          'en cours de validité, mentionnant la couverture des passagers transportés.',
      icone: Icons.shield_outlined,
    ),
    KeleganceDocumentChauffeur(
      id: 'kbis',
      titre: 'Extrait Kbis',
      instruction: 'Veuillez téléverser un Kbis de moins de 3 mois (ou équivalent pour auto-entrepreneur : '
          'avis de situation INSEE). Le document doit mentionner l\'activité de transport de personnes.',
      icone: Icons.description_outlined,
    ),
    KeleganceDocumentChauffeur(
      id: 'permis',
      titre: 'Permis de conduire',
      instruction: 'Veuillez téléverser votre permis de conduire européen en cours de validité (Recto/Verso).',
      icone: Icons.credit_card_outlined,
    ),
    KeleganceDocumentChauffeur(
      id: 'carte_grise',
      titre: 'Carte grise du véhicule',
      instruction: 'Veuillez téléverser la carte grise du véhicule affecté aux courses Kélégance. '
          'Le véhicule doit correspondre à la catégorie berline de prestige déclarée.',
      icone: Icons.directions_car_outlined,
    ),
  ];

  static const String guideSuiviCourses = '''
SUIVI DES COURSES DÉTAILLÉ

Depuis l'onglet Réservations, consultez l'ensemble des missions planifiées et en cours.

• PRENDRE LA COURSE : démarre le guidage vers le client.
• SUR PLACE : notifie le client de votre arrivée.
• CLIENT À BORD : active le GPS et le tracé vers la destination.
• TERMINER : clôture la course et déclenche la facturation automatique.

Le bandeau directionnel en haut de l'écran affiche la prochaine manœuvre. Appuyez dessus pour l'itinéraire détaillé étape par étape.
''';

  static const String guideRevenus = '''
REVENUS HEBDOMADAIRES / MENSUELS

Le chiffre d'affaires affiché sur l'écran d'accueil correspond à la somme des courses terminées sur la période en cours.

Les factures clients sont générées automatiquement dans Firestore au statut « TERMINÉ ». Votre rémunération est calculée selon votre contrat partenaire Kélégance.

Pour un relevé détaillé ou une question comptable, contactez : $contactSupport.
''';

  static const String guideParametresApp = '''
PARAMÈTRES DE L'APPLICATION

• GPS par défaut : choisissez Google Maps, Waze ou le GPS intégré Kélégance.
• Notifications : les alertes de mission et rappels 5 h00 sont gérés par l'application.
• Bulle flottante : active en arrière-plan pendant une session EN LIGNE ou en course.

Pour toute assistance technique : $contactSupport.
''';

  static String confidentialiteAvecDate() =>
      confidentialiteRgpd.replaceAll('__DATE__', _dateDuJour());

  static String _dateDuJour() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}

/// Affiche une FAQ déroulante dans une bottom sheet.
void keleganceAfficherFaq(
  BuildContext context, {
  required String titre,
  required List<KeleganceFaq> questions,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KeleganceContenuStyle.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.quiz_outlined, color: KeleganceContenuStyle.or, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final faq = questions[index];
                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.white10),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                      iconColor: KeleganceContenuStyle.or,
                      collapsedIconColor: Colors.white54,
                      title: Text(
                        faq.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faq.reponse,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Affiche un texte légal ou informatif long.
void keleganceAfficherTexteLegal(
  BuildContext context, {
  required String titre,
  required String contenu,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KeleganceContenuStyle.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.gavel_outlined, color: KeleganceContenuStyle.or, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Text(
                  contenu,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Écran documents obligatoires chauffeur.
void keleganceAfficherDocumentsChauffeur(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KeleganceContenuStyle.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_outlined, color: KeleganceContenuStyle.or, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Documents obligatoires',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Dossier partenaire — transmettez des pièces lisibles et en cours de validité. '
                'L\'équipe Kélégance valide votre dossier sous 48 h ouvrées.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: KeleganceContenus.documentsChauffeur.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = KeleganceContenus.documentsChauffeur[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KeleganceContenuStyle.or.withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(doc.icone, color: KeleganceContenuStyle.or, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                doc.titre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'À fournir',
                                style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          doc.instruction,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: KeleganceContenuStyle.or,
                              side: BorderSide(color: KeleganceContenuStyle.or.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Envoyez « ${doc.titre} » à ${KeleganceContenus.contactSupport} '
                                    'en précisant votre nom et numéro de partenaire.',
                                  ),
                                  backgroundColor: KeleganceContenuStyle.or,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload_file_outlined, size: 18),
                            label: const Text(
                              'TRANSMETTRE CE DOCUMENT',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Style minimal partagé pour les feuilles de contenu.
abstract final class KeleganceContenuStyle {
  static const Color or = Color(0xFFFFC107);
  static const Color fond = Color(0xFF0D0D0D);
}

/// Paramètres chauffeur — même finition que l'espace client (v2.3.3).
void keleganceAfficherParametresChauffeur(
  BuildContext context, {
  required String gpsLabel,
  required VoidCallback onGps,
  required VoidCallback onBasculerEspaceClient,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: KeleganceContenuStyle.fond,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 13),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PARAMÈTRES CHAUFFEUR',
                style: TextStyle(color: KeleganceContenuStyle.or, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Espace Professionnel — Kélégance Prestige',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.navigation_outlined, color: KeleganceContenuStyle.or),
                title: const Text('GPS par défaut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(gpsLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: onGps,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_special_outlined, color: KeleganceContenuStyle.or),
                title: const Text('Documents obligatoires', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Carte Pro VTC, Assurance, Kbis',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.pop(ctx);
                  keleganceAfficherDocumentsChauffeur(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.quiz_outlined, color: KeleganceContenuStyle.or),
                title: const Text('Foire aux questions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.pop(ctx);
                  keleganceAfficherFaq(context, titre: 'FAQ Chauffeur Partenaire', questions: KeleganceContenus.faqChauffeur);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_outlined, color: KeleganceContenuStyle.or),
                title: const Text("Guide de l'application", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.pop(ctx);
                  keleganceAfficherTexteLegal(
                    context,
                    titre: "Paramètres de l'application",
                    contenu: KeleganceContenus.guideParametresApp,
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onBasculerEspaceClient();
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: const Text(
                  'Basculer vers l\'Espace Client',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: KeleganceContenuStyle.or,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Prévisualisation — sans modifier votre rôle chauffeur',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Menu Aide & Support client / chauffeur.
void keleganceAfficherAideSupport(
  BuildContext context, {
  required bool chauffeur,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: KeleganceContenuStyle.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AIDE & SUPPORT',
            style: TextStyle(color: KeleganceContenuStyle.or, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'Kélégance Prestige — Cercle Privé',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 18),
          _aideLigne(
            context,
            Icons.quiz_outlined,
            'Foire aux questions',
            'Réservation, tarifs, capacité, prestations',
            onTap: () {
              Navigator.pop(ctx);
              keleganceAfficherFaq(
                context,
                titre: chauffeur ? 'FAQ Chauffeur Partenaire' : 'FAQ Client Privé',
                questions: chauffeur ? KeleganceContenus.faqChauffeur : KeleganceContenus.faqClient,
              );
            },
          ),
          if (!chauffeur) ...[
            _aideLigne(
              context,
              Icons.privacy_tip_outlined,
              'Confidentialité (RGPD)',
              'Protection des données et GPS',
              onTap: () {
                Navigator.pop(ctx);
                keleganceAfficherTexteLegal(
                  context,
                  titre: 'Politique de Confidentialité',
                  contenu: KeleganceContenus.confidentialiteAvecDate(),
                );
              },
            ),
            _aideLigne(
              context,
              Icons.description_outlined,
              'Conditions Générales de Vente',
              'Transport VTC / Chauffeur privé',
              onTap: () {
                Navigator.pop(ctx);
                keleganceAfficherTexteLegal(
                  context,
                  titre: 'Conditions Générales de Vente',
                  contenu: KeleganceContenus.conditionsGeneralesVente,
                );
              },
            ),
          ],
          _aideLigne(
            context,
            Icons.mail_outline,
            'Contacter le support',
            KeleganceContenus.contactSupport,
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Écrivez-nous à ${KeleganceContenus.contactSupport}'),
                  backgroundColor: KeleganceContenuStyle.or,
                ),
              );
            },
          ),
          if (chauffeur)
            _aideLigne(
              context,
              Icons.emergency_outlined,
              'Urgence course',
              'Utilisez le bouton SOS sur l\'écran principal',
              onTap: () => Navigator.pop(ctx),
            ),
        ],
      ),
    ),
  );
}

Widget _aideLigne(
  BuildContext context,
  IconData icone,
  String titre,
  String sousTitre, {
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icone, color: KeleganceContenuStyle.or, size: 22),
    title: Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(sousTitre, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
    trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
    onTap: onTap,
  );
}
