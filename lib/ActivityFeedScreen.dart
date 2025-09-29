import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  Future<List<String>> _getFriendsAndMe() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('senderUid', isEqualTo: myUid)
        .get();

    final snap2 = await FirebaseFirestore.instance
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('receiverUid', isEqualTo: myUid)
        .get();

    final uids = <String>{myUid};
    for (final doc in snap.docs) {
      uids.add(doc['receiverUid']);
    }
    for (final doc in snap2.docs) {
      uids.add(doc['senderUid']);
    }

    return uids.toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(
      List<String> uids) {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('actorUid', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Actividad (tú + amigos)"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: FutureBuilder<List<String>>(
        future: _getFriendsAndMe(),
        builder: (context, friendSnap) {
          if (friendSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!friendSnap.hasData || friendSnap.data!.isEmpty) {
            return const Center(
              child: Text("Todavía no tienes amigos (solo verás tus actividades)"),
            );
          }

          final uids = friendSnap.data!;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _loadActivities(uids),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No hay actividades aún"));
              }

              final activities = snapshot.data!.docs;

              return ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final data = activities[index].data();
                  final type = data['type'] ?? 'actividad';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final actorUid = data['actorUid'];

                  String description;
                  switch (type) {
                    case 'tasting':
                      description = "Degustación 🍺";
                      break;
                    case 'badgeEarned':
                      description = "¡Galardón conseguido! 🏆";
                      break;
                    case 'friendAccepted':
                      description = "Nueva amistad 🤝";
                      break;
                    default:
                      description = type.toString();
                  }

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _loadUserData(actorUid),
                    builder: (context, userSnap) {
                      final userData = userSnap.data ?? {};
                      final actorName = userData['username'] ?? "Usuario";
                      final actorPhotoUrl = userData['photoUrl'] ?? "";

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: actorPhotoUrl.isNotEmpty
                              ? NetworkImage(actorPhotoUrl)
                              : null,
                          child: actorPhotoUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(actorName),
                        subtitle: Text(
                          "$description\n${createdAt != null ? createdAt.toLocal().toString().split(' ')[0] : 'sin fecha'}",
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
