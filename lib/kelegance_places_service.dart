import 'kelegance_places_service_stub.dart'
    if (dart.library.io) 'kelegance_places_service_io.dart'
    if (dart.library.html) 'kelegance_places_service_web.dart';

abstract final class KelegancePlacesService {
  static Future<List<String>> rechercherSuggestions(String input) =>
      rechercherSuggestionsPlateforme(input);
}
