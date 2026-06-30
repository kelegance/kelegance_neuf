import 'dart:js_util' as js_util;

Future<({double km, double minutes})?> fetchDistanceMatrixPlateforme(
  String origin,
  String destination,
) async {
  final dep = origin.trim();
  final arr = destination.trim();
  if (dep.isEmpty || arr.isEmpty) return null;

  try {
    final promise = js_util.callMethod(
      js_util.globalThis,
      'keleganceDistanceMatrix',
      [dep, arr],
    );
    final raw = await js_util.promiseToFuture<Object?>(promise);
    if (raw == null) return null;

    final map = js_util.dartify(raw);
    if (map is! Map) return null;

    final km = (map['km'] as num?)?.toDouble();
    final minutes = (map['minutes'] as num?)?.toDouble();
    if (km == null || minutes == null) return null;
    return (km: km, minutes: minutes);
  } catch (_) {
    return null;
  }
}
