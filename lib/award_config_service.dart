import 'package:cloud_firestore/cloud_firestore.dart';

class AwardConfigService {
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> loadAwards() async {
    if (_cache != null) return _cache!;

    final snap = await FirebaseFirestore.instance
        .collection('config')
        .doc('awards')
        .get();

    if (!snap.exists) {
      throw Exception('No se encontro config/awards en Firestore');
    }

    final data = snap.data();
    if (data == null || !data.containsKey('json')) {
      throw Exception('El documento config/awards no contiene el campo json');
    }

    _cache = Map<String, dynamic>.from(data['json']);
    return _cache!;
  }
}
