import 'dart:async';

import 'package:flutter/material.dart';

import 'kelegance_places_service.dart';

/// Champ d'adresse avec menu déroulant de suggestions (Google Places).
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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _retirerOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus) _retirerOverlay();
      });
    }
  }

  void _onTextChanged() {
    widget.onEdited?.call();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_chargerSuggestions(widget.controller.text));
    });
  }

  Future<void> _chargerSuggestions(String text) async {
    final generation = ++_generation;
    final results = await KelegancePlacesService.rechercherSuggestions(text);
    if (!mounted || generation != _generation) return;

    setState(() => _suggestions = results);
    if (_focusNode.hasFocus && results.isNotEmpty) {
      _afficherOverlay();
    } else {
      _retirerOverlay();
    }
  }

  void _afficherOverlay() {
    _retirerOverlay();
    if (_suggestions.isEmpty || !_focusNode.hasFocus) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: _largeurChamp(ctx),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (_, index) {
                  final suggestion = _suggestions[index];
                  return InkWell(
                    onTap: () => _selectionner(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  double _largeurChamp(BuildContext ctx) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? MediaQuery.sizeOf(ctx).width - 32;
  }

  void _retirerOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectionner(String adresse) {
    widget.controller.text = adresse;
    widget.controller.selection = TextSelection.collapsed(offset: adresse.length);
    widget.onSelected?.call(adresse);
    setState(() => _suggestions = []);
    _retirerOverlay();
    _focusNode.unfocus();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: widget.style ?? const TextStyle(color: Colors.white),
        decoration: widget.decoration ?? _decorationParDefaut(),
        onTap: () {
          if (_suggestions.isNotEmpty) _afficherOverlay();
        },
      ),
    );
  }
}
