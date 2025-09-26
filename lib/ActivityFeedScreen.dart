import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities() {
    return FirebaseFirestore.instance
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadDoc(String collection, String? id) async {
    if (id == null) return null;
    final snap = await FirebaseFirestore.instance.collection(collection).doc(id).get();
    return snap.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Actividad completa")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Todavía no hay actividades"));
          }

          final activities = snapshot.data!.docs;

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final data = activities[index].data();
              final type = data['type'] ?? 'actividad';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final targets = Map<String, dynamic>.from(data['targetIds'] ?? {});

              return FutureBuilder(
                future: _buildDescription(type, data['actorUid'], targets),
                builder: (context, AsyncSnapshot<String> descSnap) {
                  final description = descSnap.data ?? type.toString();
                  return ListTile(
                    leading: const Icon(Icons.local_activity, color: Colors.blue),
                    title: Text(description),
                    subtitle: Text(
                      createdAt != null
                          ? createdAt.toLocal().toString().split(' ')[0]
                          : "sin fecha",
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Genera la descripción enriquecida de la actividad
  Future<String> _buildDescription(
      String type, String? actorUid, Map<String, dynamic> targets) async {
    // usuario
    final user =
        await _loadDoc('users', actorUid).then((d) => d?['username'] ?? 'Alguien');

    switch (type) {
      case 'tasting':
        final beer =
            await _loadDoc('beers', targets['beerId']).then((d) => d?['name'] ?? 'una cerveza');
        return "$user registró una degustación de $beer 🍺";
      case 'badgeEarned':
        return "$user consiguió un galardón 🏆";
      case 'friendAccepted':
        return "$user aceptó una amistad 🤝";
      default:
        return "$user hizo una actividad";
    }
  }
}
