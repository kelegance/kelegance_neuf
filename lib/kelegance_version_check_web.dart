import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

abstract final class KeleganceVersionCheck {
  static const String _storageKey = 'kelegance_web_build_id';

  static Future<void> verifierAuDemarrage() async {
    try {
      final origin = Uri.base.origin;
      if (origin.isEmpty) return;

      final uri = Uri.parse('$origin/version.json').replace(
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final response = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;

      final next = data['buildId']?.toString() ?? data['version']?.toString();
      if (next == null || next.isEmpty) return;

      final prev = html.window.localStorage[_storageKey];
      if (prev != null && prev != next) {
        html.window.localStorage[_storageKey] = next;
        if (kDebugMode) {
          debugPrint('Kelegance PWA — nouvelle version $next (ancienne $prev), rechargement…');
        }
        html.window.location.reload();
        return;
      }
      html.window.localStorage[_storageKey] = next;
    } catch (e) {
      if (kDebugMode) debugPrint('Kelegance version check: $e');
    }
  }
}
