import 'pricing_distance_stub.dart'
    if (dart.library.io) 'pricing_distance_io.dart'
    if (dart.library.html) 'pricing_distance_web.dart';

abstract final class KelegancePricingDistance {
  static Future<({double km, double minutes})?> fetch(String origin, String destination) =>
      fetchDistanceMatrixPlateforme(origin, destination);
}
