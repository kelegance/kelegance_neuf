import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences alertes proactives — locale + miroir Firestore pour les Cloud Functions.
abstract final class KeleganceNotificationPrefs {
  static const String _kNouvelleMission = 'kelegance_notif_nouvelle_mission_v1';
  static const String _kRappelDepart = 'kelegance_notif_rappel_depart_v1';
  static const String _kFacturePayee = 'kelegance_notif_facture_payee_v1';

  static Future<({
    bool nouvelleMission,
    bool rappelDepart1h,
    bool facturePayee,
  })> charger() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      nouvelleMission: prefs.getBool(_kNouvelleMission) ?? true,
      rappelDepart1h: prefs.getBool(_kRappelDepart) ?? true,
      facturePayee: prefs.getBool(_kFacturePayee) ?? true,
    );
  }

  static Future<void> sauvegarder({
    bool? nouvelleMission,
    bool? rappelDepart1h,
    bool? facturePayee,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (nouvelleMission != null) await prefs.setBool(_kNouvelleMission, nouvelleMission);
    if (rappelDepart1h != null) await prefs.setBool(_kRappelDepart, rappelDepart1h);
    if (facturePayee != null) await prefs.setBool(_kFacturePayee, facturePayee);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final courant = await charger();
    final payload = <String, dynamic>{
      'notificationPrefs': {
        'nouvelleMission': nouvelleMission ?? courant.nouvelleMission,
        'rappelDepart1h': rappelDepart1h ?? courant.rappelDepart1h,
        'facturePayee': facturePayee ?? courant.facturePayee,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('chauffeurs').doc(user.uid).set(payload, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('KeleganceNotificationPrefs Firestore: $e');
    }
  }
}
