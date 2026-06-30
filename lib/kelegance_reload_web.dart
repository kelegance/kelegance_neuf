import 'dart:html' as html;

abstract final class KeleganceReloadWeb {
  static Future<void> recharger() async {
    html.window.location.reload();
  }
}
