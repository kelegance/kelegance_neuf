import 'package:flutter/foundation.dart';

import 'pricing_distance.dart';

/// Résultat tarifaire partagé client / chauffeur.
class KeleganceResultatTarif {
  const KeleganceResultatTarif({required this.prix, required this.libelle});
  final double prix;
  final String libelle;
}

/// Calcul tarifaire KELEGANCE — forfaits sanctifiés + algo intelligent km.
abstract final class KeleganceTarif {
  static const String libelleForfaitAeroGare = 'Forfait Aéroport / Gare détecté et configuré';
  static const String libelleClassique = 'Tarif Course Sur-Mesure';

  static const double tarifMinimum = 15.0;
  static const double kmInclus = 3.0;
  static const double tarifKmSupplementaire = 1.80;
  static const double tauxRemiseRetourAllerRetour = 0.10;

  static const double forfaitOrlyZoneConfiance = 55.0;
  static const List<String> _zoneConfiancePartenaires = [
    'rueil', 'malmaison', 'rueil-malmaison', 'rueil malmaison',
    'saint-nom', 'saint nom', 'bretèche', 'breteche', 'nom-la-bretèche', 'nom-la-breteche',
    'saint-germain', 'germain-en-laye', 'en-laye',
    'guyancourt',
    'versailles', 'chatou', 'boulogne', 'nanterre', 'neuilly', 'le chesnay',
    'vélizy', 'velizy', 'marly', 'sartrouville', 'poissy', 'issy', 'courbevoie', 'pontoise', 'paris',
    'cloud', 'celle', 'vaucresson', 'villepreux', 'garches', 'bougival',
    'louveciennes', 'suresnes', 'meudon', 'sevres', 'sèvres', 'croissy', 'le pecq',
    'asnieres', 'asnères', 'colombes', 'levallois', 'puteaux', 'clamart', 'malakoff',
    'montrouge', 'bagneux', 'châtillon', 'chatillon', 'fontenay', 'antony', 'sceaux',
    '92500', '92400', '92800', '92000', '78100', '78400', '78000', '92380', '92210',
    '92300', '92150', '92200', '92100', '92600', '92700', '92310', '78380', '78560',
  ];

  static final RegExp _oryCodeIata = RegExp(r'\bory\b', caseSensitive: false);
  static final RegExp _orlyTerminal = RegExp(r'orly\s*[1-4]', caseSensitive: false);
  static final RegExp _orlyMotComplet = RegExp(r'\borly\b', caseSensitive: false);

  static String _normaliserTexteTarif(String texte) {
    var t = texte.toLowerCase().trim();
    const accents = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'à': 'a', 'â': 'a', 'ä': 'a',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ô': 'o', 'ö': 'o',
      'ï': 'i', 'î': 'i',
      'ç': 'c',
    };
    accents.forEach((k, v) => t = t.replaceAll(k, v));
    return t.replaceAll('-', ' ').replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _verifierZoneConfiance(String texte) {
    final t = _normaliserTexteTarif(texte);
    return _zoneConfiancePartenaires.any(t.contains);
  }

  static bool _detecterCDG(String texte) {
    final t = _normaliserTexteTarif(texte);
    return t.contains('cdg') ||
        t.contains('gaulle') ||
        t.contains('roissy') ||
        (t.contains('charles') && (t.contains('aeroport') || t.contains('airport') || t.contains('roissy')));
  }

  static bool _detecterOrly(String texte) {
    final t = _normaliserTexteTarif(texte);
    if (t.isEmpty) return false;
    if (_orlyMotComplet.hasMatch(t)) return true;
    if (t.contains('orly')) return true;
    if (_orlyTerminal.hasMatch(t)) return true;
    if (_oryCodeIata.hasMatch(t)) return true;
    if (t.contains('94390')) return true;
    if ((t.contains('aeroport') || t.contains('airport')) &&
        (t.contains('orly') || _oryCodeIata.hasMatch(t))) {
      return true;
    }
    if (t.contains('paris orly') || t.contains('orly sud') || t.contains('orly ouest')) return true;
    return false;
  }

  static bool _detecterBeauvais(String texte) {
    final t = _normaliserTexteTarif(texte);
    return t.contains('beauvais') || t.contains('bva') || t.contains('tille');
  }

  static bool _detecterGare(String texte) {
    final t = _normaliserTexteTarif(texte);
    return t.contains('gare') ||
        t.contains('montparnasse') ||
        t.contains('saint lazare') ||
        t.contains('gare de lyon') ||
        (t.contains('gare') && t.contains('nord')) ||
        t.contains('austerlitz') ||
        t.contains('bercy') ||
        (t.contains('gare') && t.contains('est'));
  }

  static bool _detecterRungis(String texte) {
    final t = _normaliserTexteTarif(texte);
    return t.contains('rungis') || t.contains('marche international');
  }

  static KeleganceResultatTarif? _forfaitOrlySecurise(String depart, String arrivee) {
    final dep = _normaliserTexteTarif(depart);
    final arr = _normaliserTexteTarif(arrivee);
    if (dep.isEmpty || arr.isEmpty) return null;

    final orlyDep = _detecterOrly(dep);
    final orlyArr = _detecterOrly(arr);
    final zoneDep = _verifierZoneConfiance(dep);
    final zoneArr = _verifierZoneConfiance(arr);

    if ((orlyDep && zoneArr) || (orlyArr && zoneDep)) {
      return const KeleganceResultatTarif(
        prix: forfaitOrlyZoneConfiance,
        libelle: libelleForfaitAeroGare,
      );
    }
    return null;
  }

  static KeleganceResultatTarif? detecterForfait(String depart, String arrivee) {
    final dep = _normaliserTexteTarif(depart);
    final arr = _normaliserTexteTarif(arrivee);
    if (dep.isEmpty || arr.isEmpty) return null;

    final orly = _forfaitOrlySecurise(depart, arrivee);
    if (orly != null) return orly;

    if ((_detecterCDG(dep) && _verifierZoneConfiance(arr)) || (_detecterCDG(arr) && _verifierZoneConfiance(dep))) {
      return const KeleganceResultatTarif(prix: 65.0, libelle: libelleForfaitAeroGare);
    }
    if ((_detecterBeauvais(dep) && _verifierZoneConfiance(arr)) || (_detecterBeauvais(arr) && _verifierZoneConfiance(dep))) {
      return const KeleganceResultatTarif(prix: 120.0, libelle: libelleForfaitAeroGare);
    }
    if ((_detecterGare(dep) && _verifierZoneConfiance(arr)) || (_detecterGare(arr) && _verifierZoneConfiance(dep))) {
      return const KeleganceResultatTarif(prix: 45.0, libelle: libelleForfaitAeroGare);
    }
    if ((_detecterRungis(dep) && _verifierZoneConfiance(arr)) || (_detecterRungis(arr) && _verifierZoneConfiance(dep))) {
      return const KeleganceResultatTarif(prix: 45.0, libelle: libelleForfaitAeroGare);
    }
    return null;
  }

  static double appliquerTarifIntelligent({required double distanceKm}) {
    if (distanceKm <= kmInclus) return tarifMinimum;
    final supplement = (distanceKm - kmInclus) * tarifKmSupplementaire;
    return double.parse((tarifMinimum + supplement).toStringAsFixed(2));
  }

  static KeleganceResultatTarif? calculerPrix(String depart, String arrivee) => detecterForfait(depart, arrivee);

  static Future<KeleganceResultatTarif?> estimerPrixComplet(String depart, String arrivee) async {
    final forfait = detecterForfait(depart, arrivee);
    if (forfait != null) return forfait;

    final dep = depart.trim();
    final arr = arrivee.trim();
    if (dep.isEmpty || arr.isEmpty) return null;

    final orlySecurise = _forfaitOrlySecurise(dep, arr);
    if (orlySecurise != null) return orlySecurise;

    final metrics = await KelegancePricingDistance.fetch(dep, arr);

    final orlyApresMatrix = _forfaitOrlySecurise(dep, arr);
    if (orlyApresMatrix != null) return orlyApresMatrix;

    if (metrics == null) {
      if (kDebugMode) {
        debugPrint('KeleganceTarif: Distance Matrix indisponible pour $dep → $arr');
      }
      return const KeleganceResultatTarif(prix: tarifMinimum, libelle: libelleClassique);
    }

    final prix = appliquerTarifIntelligent(distanceKm: metrics.km);
    return KeleganceResultatTarif(prix: prix, libelle: libelleClassique);
  }

  static double appliquerRemiseRetour(double prixTrajetRetour) {
    final remise = prixTrajetRetour * tauxRemiseRetourAllerRetour;
    return double.parse((prixTrajetRetour - remise).toStringAsFixed(2));
  }

  static double calculerTotalAllerRetour(double prixAller, {double? prixRetourBrut}) {
    final retourBrut = prixRetourBrut ?? prixAller;
    return double.parse((prixAller + appliquerRemiseRetour(retourBrut)).toStringAsFixed(2));
  }
}
