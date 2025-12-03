import 'package:cloud_firestore/cloud_firestore.dart';
import 'award_config_service.dart';

class UnlockedAward {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int level;

  UnlockedAward({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.level,
  });
}

class AwardManager {
  static Future<List<UnlockedAward>> checkAndGrantTastingAwards({
    required String uid,
    required int tastingsTotal,
  }) async {
    final db = FirebaseFirestore.instance;
    final config = await AwardConfigService.loadAwards();
    final List<dynamic> allAwards = config['galardones'] ?? [];

    final List<UnlockedAward> result = [];

    for (final raw in allAwards) {
      final award = Map<String, dynamic>.from(raw);

      if (award['metric'] != 'tastingsTotal') continue;

      final String awardId = award['id'];
      final List<int> niveles =
          (award['niveles'] as List).map((e) => (e as num).toInt()).toList();

      // Calcular nivel
      int newLevel = 0;
      for (int i = 0; i < niveles.length; i++) {
        if (tastingsTotal >= niveles[i]) newLevel = i + 1;
      }

      if (newLevel == 0) continue;

      final badgeRef =
          db.collection('users').doc(uid).collection('badges').doc(awardId);
      final badgeSnap = await badgeRef.get();

      final int oldLevel = badgeSnap.data()?['level'] is num
          ? (badgeSnap.data()!['level'] as num).toInt()
          : 0;

      if (newLevel <= oldLevel) continue;

      await db.runTransaction((tx) async {
        tx.set(
          badgeRef,
          {
            'level': newLevel,
            'name': award['nombre'],
            'description': award['descripcion'],
            'imageUrl': award['imagen'],
            'earnedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (oldLevel == 0) {
          tx.set(
            db.collection('users').doc(uid),
            {
              'stats': {'badgesCount': FieldValue.increment(1)}
            },
            SetOptions(merge: true),
          );
        }
      });

      await db.collection('notificaciones').add({
        'uid': uid,
        'nombre': award['nombre'],
        'nivel': newLevel,
        'fecha': FieldValue.serverTimestamp(),
        'tipo': 'galardon',
      });

      result.add(
        UnlockedAward(
          id: awardId,
          name: award['nombre'],
          description: award['descripcion'],
          imageUrl: award['imagen'],
          level: newLevel,
        ),
      );
    }

    return result;
  }
}
