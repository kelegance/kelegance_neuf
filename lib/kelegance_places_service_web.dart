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
    if (raw == null) return const [];

    final list = js_util.dartify(raw);
    if (list is! List) return const [];

    return list
        .map((e) {
          if (e is Map) {
            final description = e['description'];
            if (description != null) return description.toString();
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .take(6)
        .toList();
  } catch (_) {
    return const [];
  }
}
