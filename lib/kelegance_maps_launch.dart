import 'kelegance_maps_launch_stub.dart'
    if (dart.library.html) 'kelegance_maps_launch_web.dart';

abstract final class KeleganceMapsLaunch {
  static void ouvrirNatif(String adresse) => ouvrirMapsNativeWeb(adresse);
}
