import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modes de paiement Espace Client — v3.5.0 (Stripe / carte à bord / espèces).
enum KeleganceModePaiement {
  carteBancaire('a_bord', 'Carte bancaire (à bord)'),
  especes('especes_bord', 'Espèces (à bord)'),
  stripe('stripe', 'Paiement sécurisé via Stripe');

  const KeleganceModePaiement(this.id, this.libelle);
  final String id;
  final String libelle;
}

/// Simulation Stripe Mode Test — prêt pour branchement SDK production.
abstract final class KeleganceStripePaiement {
  static const bool modeTest = true;
  static const String libelleTicket = 'Paiement sécurisé via Stripe';
  static const String statutMissionPaye = 'EN ATTENTE';

  static const Set<String> _cartesTestValides = {
    '4242424242424242',
    '4000056655665556',
    '5555555555554444',
  };

  static String? libelleAffichage(Map<String, dynamic>? data) {
    if (data == null) return null;
    final mode = data['modePaiement']?.toString();
    if (mode == KeleganceModePaiement.stripe.id || data['paiementLabel'] != null) {
      return data['paiementLabel']?.toString() ?? libelleTicket;
    }
    for (final option in KeleganceModePaiement.values) {
      if (option.id == mode) return option.libelle;
    }
    return null;
  }

  static Map<String, dynamic> champsFirestoreStripe() => {
        'modePaiement': KeleganceModePaiement.stripe.id,
        'paiementLabel': libelleTicket,
        'paiementStatut': 'carte_enregistree',
        'stripeTestMode': modeTest,
        'stripeMode': 'test',
      };

  static bool estStripe(Map<String, dynamic>? data) =>
      data?['modePaiement']?.toString() == KeleganceModePaiement.stripe.id;

  /// Simule le débit automatique Stripe en fin de course (Mode Test).
  static Future<bool> debiterFinDeCourse(
    BuildContext context, {
    required double montant,
  }) async {
    return ouvrirFormulaireTest(context, montant: montant, titre: 'Débit automatique Stripe');
  }

  static String _chiffresCarte(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String formaterNumeroCarte(String value) {
    final digits = _chiffresCarte(value);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String formaterExpiration(String value) {
    final digits = _chiffresCarte(value);
    if (digits.length <= 2) return digits;
    return '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(2, 4))}';
  }

  static bool carteTestValide(String numero) {
    final digits = _chiffresCarte(numero);
    if (_cartesTestValides.contains(digits)) return true;
    return digits.startsWith('4242') && digits.length == 16;
  }

  static bool expirationValide(String expiration) {
    final parts = expiration.split('/');
    if (parts.length != 2) return false;
    final mois = int.tryParse(parts[0]);
    final annee = int.tryParse(parts[1]);
    if (mois == null || annee == null || mois < 1 || mois > 12) return false;
    final fullYear = annee < 100 ? 2000 + annee : annee;
    final finMois = DateTime(fullYear, mois + 1);
    return finMois.isAfter(DateTime.now());
  }

  /// Ouvre le faux formulaire CB sécurisé (charte Noir & Jaune) et simule le paiement.
  static Future<bool> ouvrirFormulaireTest(
    BuildContext context, {
    required double montant,
    String titre = 'Enregistrement carte Stripe',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StripeFormulaireTestSheet(montant: montant, titre: titre),
    );
    return result == true;
  }
}

class _StripeFormulaireTestSheet extends StatefulWidget {
  final double montant;
  final String titre;

  const _StripeFormulaireTestSheet({required this.montant, required this.titre});

  @override
  State<_StripeFormulaireTestSheet> createState() => _StripeFormulaireTestSheetState();
}

class _StripeFormulaireTestSheetState extends State<_StripeFormulaireTestSheet> {
  final _numeroCtrl = TextEditingController();
  final _expirationCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  static const _or = Color(0xFFFFC107);
  static const _fond = Color(0xFF0D0D0D);

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _expirationCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  Future<void> _payer() async {
    setState(() {
      _erreur = null;
      _enCours = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));

    final numero = KeleganceStripePaiement._chiffresCarte(_numeroCtrl.text);
    final expiration = _expirationCtrl.text.trim();
    final cvc = KeleganceStripePaiement._chiffresCarte(_cvcCtrl.text);

    if (!KeleganceStripePaiement.carteTestValide(numero)) {
      setState(() {
        _enCours = false;
        _erreur = 'Carte refusée. Utilisez 4242 4242 4242 4242 (mode test).';
      });
      return;
    }
    if (!KeleganceStripePaiement.expirationValide(expiration)) {
      setState(() {
        _enCours = false;
        _erreur = 'Date d\'expiration invalide (ex : 12/34).';
      });
      return;
    }
    if (cvc.length < 3) {
      setState(() {
        _enCours = false;
        _erreur = 'Code CVC invalide.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _fond,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: _or, width: 1.5)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _or.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _or.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: _or, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titre,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          'Mode Test — carte 4242 4242 4242 4242',
                          style: TextStyle(color: _or, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _or.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant à régler', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      '${widget.montant.toStringAsFixed(2)} €',
                      style: const TextStyle(color: _or, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _champ(
                controller: _numeroCtrl,
                label: 'Numéro de carte',
                hint: '4242 4242 4242 4242',
                keyboard: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CarteInputFormatter(),
                ],
                icon: Icons.credit_card,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _champ(
                      controller: _expirationCtrl,
                      label: 'Expiration',
                      hint: 'MM/AA',
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpirationInputFormatter(),
                      ],
                      icon: Icons.date_range_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _champ(
                      controller: _cvcCtrl,
                      label: 'CVC',
                      hint: '123',
                      keyboard: TextInputType.number,
                      obscure: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      icon: Icons.password_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Cartes de test : 4242 4242 4242 4242',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _or,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _enCours ? null : _payer,
                  icon: _enCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(
                    _enCours ? 'Traitement sécurisé…' : 'PAYER ${widget.montant.toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              TextButton(
                onPressed: _enCours ? null : () => Navigator.pop(context, false),
                child: Text('Annuler', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _champ({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboard,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _or, fontSize: 12),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
        prefixIcon: Icon(icon, color: _or.withValues(alpha: 0.8), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _or.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _or, width: 1.4),
        ),
      ),
    );
  }
}

class _CarteInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = KeleganceStripePaiement.formaterNumeroCarte(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpirationInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = KeleganceStripePaiement.formaterExpiration(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Ligne ticket récapitulatif client / chauffeur.
Widget keleganceLignePaiementTicket(Map<String, dynamic>? data) {
  final libelle = KeleganceStripePaiement.libelleAffichage(data);
  if (libelle == null) return const SizedBox.shrink();
  const or = Color(0xFFFFC107);
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(Icons.payments_outlined, color: or.withValues(alpha: 0.75), size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Paiement : $libelle',
            style: TextStyle(
              color: or.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
