import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kelegance_bon_commande_service.dart';

/// Formulaire mobile rapide — bon de commande retour.
abstract final class KeleganceBonCommandeForm {
  static const Color _or = Color(0xFFD4AF37);

  static Future<void> afficher(BuildContext context) async {
    final peutCreer = await KeleganceBonCommandeService.utilisateurPeutCreer();
    if (!context.mounted) return;
    if (!peutCreer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Création réservée aux profils chauffeur / Bras Droit.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => const _BonRetourFormSheet(),
    );
  }
}

enum _EtatRechercheClient { initial, enCours, trouve, introuvable, invalide }

class _BonRetourFormSheet extends StatefulWidget {
  const _BonRetourFormSheet();

  @override
  State<_BonRetourFormSheet> createState() => _BonRetourFormSheetState();
}

class _BonRetourFormSheetState extends State<_BonRetourFormSheet> {
  static const Color _or = Color(0xFFD4AF37);

  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();

  Timer? _debounceRecherche;
  DateTime _dateTransfert = DateTime.now();
  bool _enregistrement = false;
  _EtatRechercheClient _etatClient = _EtatRechercheClient.initial;
  KeleganceClientResolu? _clientResolu;
  String? _messageClient;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_planifierRechercheClient);
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _emailCtrl.removeListener(_planifierRechercheClient);
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _destinationCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  void _planifierRechercheClient() {
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 450), () {
      unawaited(_rechercherClient());
    });
  }

  Future<void> _rechercherClient() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _etatClient = _EtatRechercheClient.initial;
        _clientResolu = null;
        _messageClient = null;
      });
      return;
    }

    if (KeleganceBonCommandeService.normaliserEmailClient(email) == null) {
      setState(() {
        _etatClient = _EtatRechercheClient.invalide;
        _clientResolu = null;
        _messageClient = 'Format e-mail invalide';
      });
      return;
    }

    setState(() {
      _etatClient = _EtatRechercheClient.enCours;
      _messageClient = 'Recherche du client…';
    });

    try {
      final client = await KeleganceBonCommandeService.rechercherClientParEmail(email);
      if (!mounted) return;

      if (client == null) {
        setState(() {
          _etatClient = _EtatRechercheClient.introuvable;
          _clientResolu = null;
          _messageClient = 'Client introuvable dans la base';
        });
        return;
      }

      setState(() {
        _etatClient = _EtatRechercheClient.trouve;
        _clientResolu = client;
        _messageClient = 'Client lié · ${client.nom}';
        if (_nomCtrl.text.trim().isEmpty) {
          _nomCtrl.text = client.nom;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _etatClient = _EtatRechercheClient.introuvable;
        _clientResolu = null;
        _messageClient = 'Erreur de recherche : $e';
      });
    }
  }

  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTransfert,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(primary: _or),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _dateTransfert = picked);
  }

  Future<void> _enregistrer() async {
    final nom = _nomCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final destination = _destinationCtrl.text.trim();
    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (email.isEmpty) {
      _afficherAlerte('L\'e-mail client est obligatoire pour lier le bon à son espace.');
      return;
    }
    if (nom.isEmpty || destination.isEmpty || montant <= 0) {
      _afficherAlerte('Nom, destination et montant sont requis.');
      return;
    }

    if (_etatClient == _EtatRechercheClient.enCours) {
      _afficherAlerte('Patientez — vérification du client en cours.');
      return;
    }

    setState(() => _enregistrement = true);
    try {
      if (_clientResolu == null || _etatClient != _EtatRechercheClient.trouve) {
        await _rechercherClient();
        if (_clientResolu == null) {
          if (!mounted) return;
          await _afficherClientIntrouvable(email);
          return;
        }
      }

      final client = _clientResolu!;
      await KeleganceBonCommandeService.creer(
        KeleganceBonCommandeRetour(
          clientNom: nom.isNotEmpty ? nom : client.nom,
          clientEmail: client.email,
          clientId: client.uid,
          dateTransfert: _dateTransfert,
          destination: destination,
          montant: montant,
          statut: KeleganceBonCommandeService.statutInitial,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Bon de commande retour enregistré — ${client.nom} → $destination'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on KeleganceClientIntrouvableException catch (e) {
      if (!mounted) return;
      await _afficherClientIntrouvable(e.email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  void _afficherAlerte(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.orange, content: Text(message)),
    );
  }

  Future<void> _afficherClientIntrouvable(String email) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_off_outlined, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Client introuvable',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          'Aucun profil client enregistré pour :\n$email\n\n'
          'Vérifiez l\'adresse ou créez le compte client avant d\'émettre le bon.',
          style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _or)),
          ),
        ],
      ),
    );
  }

  Color get _couleurEtatClient {
    switch (_etatClient) {
      case _EtatRechercheClient.trouve:
        return Colors.greenAccent;
      case _EtatRechercheClient.introuvable:
      case _EtatRechercheClient.invalide:
        return Colors.redAccent;
      case _EtatRechercheClient.enCours:
        return Colors.amber;
      case _EtatRechercheClient.initial:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bas),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'BON DE COMMANDE RETOUR',
            style: TextStyle(
              color: _or,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Liaison client automatique par e-mail',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
          ),
          const SizedBox(height: 18),
          _champEmailClient(),
          const SizedBox(height: 12),
          _champ(_nomCtrl, label: 'Nom du client', icone: Icons.person_outline),
          const SizedBox(height: 12),
          InkWell(
            onTap: _enregistrement ? null : _choisirDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: _decoration('Date du transfert', Icons.event_outlined),
              child: Text(
                '${_dateTransfert.day.toString().padLeft(2, '0')}/'
                '${_dateTransfert.month.toString().padLeft(2, '0')}/'
                '${_dateTransfert.year}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _champ(_destinationCtrl, label: 'Destination (ex: Guyancourt)', icone: Icons.place_outlined),
          const SizedBox(height: 12),
          _champ(
            _montantCtrl,
            label: 'Montant (€)',
            icone: Icons.euro,
            clavier: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: _decoration('Statut', Icons.hourglass_top_outlined),
            child: Text(
              KeleganceBonCommandeService.statutInitial,
              style: TextStyle(color: Colors.orangeAccent.withOpacity(0.95), fontSize: 14),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _or,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(
                _enregistrement ? 'Enregistrement…' : 'Enregistrer',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _champEmailClient() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: Colors.white),
          decoration: _decoration('E-mail client', Icons.alternate_email).copyWith(
            suffixIcon: _etatClient == _EtatRechercheClient.enCours
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _or),
                    ),
                  )
                : Icon(
                    _etatClient == _EtatRechercheClient.trouve
                        ? Icons.check_circle
                        : _etatClient == _EtatRechercheClient.introuvable ||
                                _etatClient == _EtatRechercheClient.invalide
                            ? Icons.error_outline
                            : Icons.search,
                    color: _couleurEtatClient,
                    size: 20,
                  ),
          ),
        ),
        if (_messageClient != null) ...[
          const SizedBox(height: 6),
          Text(
            _messageClient!,
            style: TextStyle(color: _couleurEtatClient, fontSize: 11),
          ),
        ],
        if (_clientResolu != null) ...[
          const SizedBox(height: 4),
          Text(
            'ID client : ${_clientResolu!.uid}',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9),
          ),
        ],
      ],
    );
  }

  InputDecoration _decoration(String label, IconData icone) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _or.withOpacity(0.85), fontSize: 12),
      prefixIcon: Icon(icone, color: _or.withOpacity(0.75), size: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _or.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _or.withOpacity(0.7)),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _champ(
    TextEditingController controller, {
    required String label,
    required IconData icone,
    TextInputType clavier = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: clavier,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label, icone),
    );
  }
}

/// Liste live des bons de commande retour.
class KeleganceListeBonsCommandeRetour extends StatelessWidget {
  const KeleganceListeBonsCommandeRetour({
    super.key,
    this.modeExpert = false,
    this.titre = 'BONS DE COMMANDE RETOUR',
  });

  final bool modeExpert;
  final String titre;

  static const Color _or = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final mail = user?.email?.trim().toLowerCase();
    final uid = user?.uid;

    return KeleganceBonsCommandeStreamBuilder(
      filtre: modeExpert
          ? null
          : (docs) => docs
              .where((d) => KeleganceBonCommandeService.peutVoirBon(
                    d.data() as Map<String, dynamic>,
                    email: mail,
                    uid: uid,
                  ))
              .toList(),
      builder: (context, snapshot, live) {
        if (snapshot == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final docs = KeleganceBonCommandeService.trierParDateRecente(snapshot.docs);

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aucun bon de commande retour.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return_outlined, color: _or.withOpacity(0.9), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      color: _or,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (live)
                  Text(
                    'live',
                    style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 9),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) => _CarteBonRetour(
                  data: doc.data() as Map<String, dynamic>,
                  modeExpert: modeExpert,
                  miseAJourLive: live,
                )),
          ],
        );
      },
    );
  }
}

class _CarteBonRetour extends StatelessWidget {
  const _CarteBonRetour({
    required this.data,
    required this.modeExpert,
    this.miseAJourLive = false,
  });

  final Map<String, dynamic> data;
  final bool modeExpert;
  final bool miseAJourLive;

  static const Color _or = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final client = data['clientNom']?.toString() ?? 'Client';
    final destination = data['destination']?.toString() ?? '—';
    final date = data['dateTransfert']?.toString() ?? '—';
    final montant = KeleganceBonCommandeService.parserMontant(data);
    final statut = KeleganceBonCommandeService.presenterStatut(data['statut']?.toString());
    final auteur = data['auteurNom']?.toString() ?? data['auteurEmail']?.toString() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: miseAJourLive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.08), blurRadius: 6)],
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFF101010),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _or.withOpacity(0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_return, color: statut.couleur, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${montant.toStringAsFixed(2)} €',
                    style: const TextStyle(color: _or, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('$date · $destination', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              if (modeExpert && auteur.isNotEmpty == false) ...[
                const SizedBox(height: 4),
                Text('Par $auteur', style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 10)),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statut.couleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statut.libelle,
                  style: TextStyle(color: statut.couleur, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
