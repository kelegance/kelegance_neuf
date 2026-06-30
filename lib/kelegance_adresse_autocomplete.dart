import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kelegance_places_service.dart';

/// Champ d'adresse avec suggestions Google Places — liste inline (fiable sur Android).
class KeleganceAdresseAutocomplete extends StatefulWidget {
  const KeleganceAdresseAutocomplete({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.decoration,
    this.style,
    this.onEdited,
    this.onSelected,
  });

  static const double hauteurListeSuggestions = 220;

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final InputDecoration? decoration;
  final TextStyle? style;
  final VoidCallback? onEdited;
  final ValueChanged<String>? onSelected;

  @override
  State<KeleganceAdresseAutocomplete> createState() => _KeleganceAdresseAutocompleteState();
}

class _KeleganceAdresseAutocompleteState extends State<KeleganceAdresseAutocomplete> {
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  Timer? _debounce;
  Timer? _fermetureListe;
  int _generation = 0;
  bool _chargementEnCours = false;
  bool _selectionEnCours = false;

  bool get _panneauVisible =>
      _focusNode.hasFocus &&
      !_selectionEnCours &&
      (widget.controller.text.trim().length >= 2 || _chargementEnCours);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fermetureListe?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_selectionEnCours) return;
    setState(() {});

    if (_focusNode.hasFocus) {
      _fermetureListe?.cancel();
      final query = widget.controller.text.trim();
      if (query.length >= 2) {
        unawaited(_chargerSuggestions(query));
      }
      return;
    }

    _fermetureListe?.cancel();
    _fermetureListe = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _selectionEnCours || _focusNode.hasFocus) return;
      setState(() {
        _suggestions = [];
        _chargementEnCours = false;
      });
    });
  }

  void _onTextChanged() {
    if (_selectionEnCours) return;
    widget.onEdited?.call();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_chargerSuggestions(widget.controller.text));
    });
  }

  Future<void> _chargerSuggestions(String text) async {
    final query = text.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _chargementEnCours = false;
      });
      return;
    }

    final generation = ++_generation;
    if (mounted) setState(() => _chargementEnCours = true);

    final results = await KelegancePlacesService.rechercherSuggestions(query);
    if (!mounted || generation != _generation || _selectionEnCours) return;

    setState(() {
      _suggestions = results;
      _chargementEnCours = false;
    });
  }

  void selectionnerAdresse(String adresse) {
    if (adresse.trim().isEmpty || _selectionEnCours) return;

    _selectionEnCours = true;
    _debounce?.cancel();
    _fermetureListe?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    widget.controller.text = adresse;
    widget.controller.selection = TextSelection.collapsed(offset: adresse.length);
    widget.onSelected?.call(adresse);

    setState(() {
      _suggestions = [];
      _chargementEnCours = false;
    });

    _focusNode.unfocus();

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _selectionEnCours = false);
    });
  }

  InputDecoration _decorationParDefaut() {
    return InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      filled: true,
      fillColor: Colors.white10,
      hintStyle: const TextStyle(color: Colors.white38),
      labelStyle: const TextStyle(color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.amber, width: 0.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
      suffixIcon: _chargementEnCours
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
              ),
            )
          : const Icon(Icons.search, color: Colors.white38, size: 20),
    );
  }

  Widget _buildListeSuggestions() {
    if (_chargementEnCours && _suggestions.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          'Aucune suggestion — vérifiez Places API sur la clé Android',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, index) {
        final suggestion = _suggestions[index];
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => selectionnerAdresse(suggestion),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.place_outlined, color: Colors.amber, size: 18),
            title: Text(
              suggestion,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: widget.style ?? const TextStyle(color: Colors.white),
          decoration: widget.decoration ?? _decorationParDefaut(),
          onTap: () {
            if (!_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }
            final query = widget.controller.text.trim();
            if (query.length >= 2) {
              unawaited(_chargerSuggestions(query));
            }
          },
        ),
        if (_panneauVisible) ...[
          const SizedBox(height: 6),
          Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A2332),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: KeleganceAdresseAutocomplete.hauteurListeSuggestions,
              child: _buildListeSuggestions(),
            ),
          ),
        ],
      ],
    );
  }
}
