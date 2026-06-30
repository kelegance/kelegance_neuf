import 'dart:async';

import 'package:flutter/material.dart';

import 'kelegance_roles.dart';

/// Bandeau diagnostic — comprendre pourquoi les droits Bras Droit ne s'appliquent pas.
class KeleganceRolesDiagnostic extends StatefulWidget {
  const KeleganceRolesDiagnostic({super.key});

  @override
  State<KeleganceRolesDiagnostic> createState() => _KeleganceRolesDiagnosticState();
}

class _KeleganceRolesDiagnosticState extends State<KeleganceRolesDiagnostic> {
  Map<String, dynamic>? _infos;
  bool _chargement = false;

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final infos = await KeleganceRoles.diagnosticAcces();
    if (!mounted) return;
    setState(() {
      _infos = infos;
      _chargement = false;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  @override
  Widget build(BuildContext context) {
    const or = Color(0xFFD4AF37);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: or.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report_outlined, color: or, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DIAGNOSTIC ACCÈS',
                  style: TextStyle(color: or, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vérifie la résolution Bras Droit (liste officielle + Firestore).',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (_chargement)
            const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: or)))
          else if (_infos != null)
            ..._infos!.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${e.key} : ${e.value}',
                  style: TextStyle(
                    color: e.key == 'accesEffectif' && e.value == true ? Colors.greenAccent : Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _chargement ? null : _charger,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Rafraîchir le diagnostic', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: or,
              side: BorderSide(color: or.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
