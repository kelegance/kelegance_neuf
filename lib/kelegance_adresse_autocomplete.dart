import 'dart:async';

import 'package:flutter/material.dart';

import 'kelegance_places_service.dart';

/// Champ d'adresse avec suggestions Google Places — liste inline (hors formulaires critiques).
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
  int _generation = 0;
  bool _chargementEnCours = false;
  bool _selectionEnCours = false;

  bool get _panneauVisible =>
      _focusNode.hasFocus &&
      !_selectionEnCours &&
      _suggestions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_selectionEnCours) return;
    widget.onEdited?.call();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_chargerSuggestions(widget.controller.text));
    });
  }

  Future<void> _chargerSuggestions(String text) async {
    final query = text.trim();
    if (query.length < 3 || !_focusNode.hasFocus) {
      if (!mounted) return;
      if (_suggestions.isNotEmpty || _chargementEnCours) {
        setState(() {
          _suggestions = [];
          _chargementEnCours = false;
        });
      }
      return;
    }

    final generation = ++_generation;
    if (mounted && !_chargementEnCours) setState(() => _chargementEnCours = true);

    final results = await KelegancePlacesService.rechercherSuggestions(query);
    if (!mounted || generation != _generation || _selectionEnCours || !_focusNode.hasFocus) return;

    setState(() {
      _suggestions = results;
      _chargementEnCours = false;
    });
  }

  void selectionnerAdresse(String adresse) {
    if (adresse.trim().isEmpty || _selectionEnCours) return;

    _selectionEnCours = true;
    _debounce?.cancel();
    widget.controller.text = adresse;
    widget.controller.selection = TextSelection.collapsed(offset: adresse.length);
    widget.onSelected?.call(adresse);

    setState(() {
      _suggestions = [];
      _chargementEnCours = false;
    });

    Future<void>.delayed(const Duration(milliseconds: 80), () {
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
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.place_outlined, color: Colors.amber, size: 18),
          title: Text(
            suggestion,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => selectionnerAdresse(suggestion),
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
          enabled: true,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.next,
          style: widget.style ?? const TextStyle(color: Colors.white),
          decoration: widget.decoration ?? _decorationParDefaut(),
          onTapOutside: (_) {
            _focusNode.unfocus();
            if (_suggestions.isNotEmpty) {
              setState(() => _suggestions = []);
            }
          },
        ),
        if (_panneauVisible) ...[
          const SizedBox(height: 6),
          Material(
            elevation: 4,
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
