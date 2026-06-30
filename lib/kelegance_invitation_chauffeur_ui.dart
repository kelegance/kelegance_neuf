import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'kelegance_invitation_chauffeur.dart';
import 'kelegance_roles.dart';
import 'qr_generator_page.dart';

/// Formulaire Bras Droit — création d'un profil chauffeur collaborateur + lien sécurisé.
class KelegancePageInvitationEquipe extends StatefulWidget {
  const KelegancePageInvitationEquipe({super.key});

  @override
  State<KelegancePageInvitationEquipe> createState() => _KelegancePageInvitationEquipeState();
}

class _KelegancePageInvitationEquipeState extends State<KelegancePageInvitationEquipe> {
  static const Color _or = Color(0xFFD4AF37);
  static const Color _fond = Color(0xFF0B1426);

  final _formKey = GlobalKey<FormState>();
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();

  bool _enCours = false;
  String? _lienGenere;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _creerProfil() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _lienGenere = null;
    });
    try {
      final lien = await KeleganceInvitationChauffeur.creerEtGenererLien(
        prenom: _prenomController.text.trim(),
        nom: _nomController.text.trim(),
        email: _emailController.text.trim(),
        telephone: _telephoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _lienGenere = lien);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D52),
          content: Text('Profil chauffeur créé — lien de connexion prêt.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!KeleganceRoles.peutGererInvitationsChauffeur()) {
      return Scaffold(
        backgroundColor: _fond,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: _or),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Accès réservé aux Bras Droit Kelegance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _or),
        title: const Text(
          'ÉQUIPE — NOUVEAU CHAUFFEUR',
          style: TextStyle(color: _or, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.6),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'QR Codes équipe',
            icon: const Icon(Icons.qr_code_2_rounded, color: _or),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Créez un profil chauffeur collaborateur (accès restreint : dispatcher, missions, QRC).',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 24),
                _champ('Prénom', _prenomController, Icons.person_outline),
                const SizedBox(height: 14),
                _champ('Nom', _nomController, Icons.badge_outlined),
                const SizedBox(height: 14),
                _champ(
                  'E-mail professionnel',
                  _emailController,
                  Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final mail = v?.trim() ?? '';
                    if (!mail.contains('@')) return 'E-mail invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _champ('Téléphone (optionnel)', _telephoneController, Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _enCours ? null : _creerProfil,
                  icon: _enCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(_enCours ? 'Création…' : 'Créer le profil chauffeur'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _or,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_lienGenere != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121E33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _or.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'LIEN DE CONNEXION SÉCURISÉ',
                          style: TextStyle(color: _or, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _lienGenere!,
                          style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => KeleganceInvitationChauffeur.copierLien(context, _lienGenere!),
                                icon: const Icon(Icons.link_rounded, size: 16),
                                label: const Text('Copier', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(foregroundColor: _or, side: BorderSide(color: _or.withOpacity(0.45))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Share.share(
                                  'Bonjour,\n\nVoici votre lien de connexion sécurisé Kelegance (espace chauffeur) :\n\n${_lienGenere!}\n\nÀ bientôt,\nL\'équipe KELEGANCE',
                                  subject: 'Kelegance — accès chauffeur',
                                ),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Partager', style: TextStyle(fontSize: 11)),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D52), foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _champ(
    String label,
    TextEditingController controller,
    IconData icone, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
        prefixIcon: Icon(icone, color: _or.withOpacity(0.85), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _or.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _or),
        ),
      ),
    );
  }
}
