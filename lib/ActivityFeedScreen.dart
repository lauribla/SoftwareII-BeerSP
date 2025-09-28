import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities() {
    return FirebaseFirestore.instance
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Actividad completa"),
        leading: BackButton(onPressed: () => context.pop()), // 🔙 volver atrás
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Todavía no hay actividades"),
            );
          }

          final activities = snapshot.data!.docs;

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final data = activities[index].data();
              final type = data['type'] ?? 'actividad';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final beerId = data['targetIds']?['beerId'];

              if (type == 'tasting' && beerId != null) {
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('beers')
                      .doc(beerId)
                      .get(),
                  builder: (context, beerSnap) {
                    if (beerSnap.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: Icon(Icons.local_drink),
                        title: Text("Cargando degustación..."),
                      );
                    }

                    if (!beerSnap.hasData || !beerSnap.data!.exists) {
                      return ListTile(
                        leading: const Icon(Icons.error),
                        title: const Text("Cerveza desconocida"),
                        subtitle: Text(
                          createdAt != null
                              ? createdAt.toLocal().toString().split(' ')[0]
                              : 'sin fecha',
                        ),
                      );
                    }

                    final beer = beerSnap.data!.data()!;
                    final name = beer['name'] ?? 'Cerveza';
                    final style = beer['style'] ?? '—';

                    return ListTile(
                      leading: const Icon(Icons.local_drink),
                      title: Text("Degustación: $name"),
                      subtitle: Text(
                        "$style\n${createdAt != null ? createdAt.toLocal().toString().split(' ')[0] : 'sin fecha'}",
                      ),
                    );
                  },
                );
              }

              // Otros tipos de actividad
              String description;
              switch (type) {
                case 'badgeEarned':
                  description = "¡Galardón conseguido! 🏆";
                  break;
                case 'friendAccepted':
                  description = "Nueva amistad aceptada 🤝";
                  break;
                default:
                  description = type.toString();
              }

              return ListTile(
                leading: const Icon(Icons.local_activity, color: Colors.blue),
                title: Text(description),
                subtitle: Text(
                  createdAt != null
                      ? createdAt.toLocal().toString().split(' ')[0]
                      : 'sin fecha',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
