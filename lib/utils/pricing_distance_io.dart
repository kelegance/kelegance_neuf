import 'dart:convert';

import 'package:http/http.dart' as http;

const _apiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI',
);

Future<({double km, double minutes})?> fetchDistanceMatrixPlateforme(
  String origin,
  String destination,
) async {
  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${Uri.encodeComponent(origin)}'
      '&destinations=${Uri.encodeComponent(destination)}'
      '&mode=driving'
      '&language=fr'
      '&units=metric'
      '&key=$_apiKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;

    final elements = (json['rows'] as List?)?.first?['elements'] as List?;
    final element = elements?.isNotEmpty == true ? elements!.first as Map<String, dynamic> : null;
    if (element == null || element['status'] != 'OK') return null;

    final meters = (element['distance'] as Map)['value'] as int;
    final seconds = (element['duration'] as Map)['value'] as int;
    return (km: meters / 1000.0, minutes: seconds / 60.0);
  } catch (_) {
    return null;
  }
}
