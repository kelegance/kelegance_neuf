import 'dart:js_util' as js_util;

Future<List<String>> rechercherSuggestionsPlateforme(String input) async {
  final query = input.trim();
  if (query.length < 2) return const [];

  try {
    final promise = js_util.callMethod(
      js_util.globalThis,
      'kelegancePlacesAutocomplete',
      [query],
    );
    final raw = await js_util.promiseToFuture<Object?>(promise);
    if (raw is! List) return const [];

    return raw
        .map((e) {
          if (e is Map) return e['description']?.toString() ?? '';
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .take(6)
        .toList();
  } catch (_) {
    return const [];
  }
}
