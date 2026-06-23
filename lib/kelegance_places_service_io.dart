import 'dart:convert';

import 'package:http/http.dart' as http;

const _apiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI',
);

Future<List<String>> rechercherSuggestionsPlateforme(String input) async {
  final query = input.trim();
  if (query.length < 2) return const [];

  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&language=fr'
      '&components=country:fr'
      '&key=$_apiKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return const [];

    final predictions = json['predictions'] as List?;
    if (predictions == null || predictions.isEmpty) return const [];

    return predictions
        .map((p) => (p as Map<String, dynamic>)['description']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .take(6)
        .toList();
  } catch (_) {
    return const [];
  }
}
