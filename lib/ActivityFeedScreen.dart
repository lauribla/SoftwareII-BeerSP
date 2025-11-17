import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'AvatarUsuario.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  Future<List<String>> _getFriendsAndMe() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .get();
    final friends = List<String>.from(doc.data()?['friends'] ?? []);
    return [myUid, ...friends];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(
    List<String> uids,
  ) {
    if (uids.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('activities')
        .where('actorUid', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
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

          final uids = friendSnap.data ?? [];
          if (uids.isEmpty) {
            return const Center(
              child: Text(
                "Todavía no tienes amigos (solo verás tus actividades)",
              ),
            );
          }

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
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final actorUid = data['actorUid'] as String? ?? '';
                  final type = (data['type'] ?? '').toString().toLowerCase();

                  final tastingId =
                      (data['targetIds'] is Map &&
                          (data['targetIds'] as Map).containsKey('tastingId'))
                      ? data['targetIds']['tastingId']
                      : data['tastingId'];

                  // Solo degustaciones
                  if (type == 'tasting' && tastingId != null) {
                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: FirebaseFirestore.instance
                          .collection('tastings')
                          .doc(tastingId)
                          .get(),
                      builder: (context, tastingSnap) {
                        if (!tastingSnap.hasData || !tastingSnap.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final tasting = tastingSnap.data!.data()!;
                        final beerId = tasting['beerId'] as String;
                        final rating = (tasting['rating'] ?? 0).toStringAsFixed(
                          1,
                        );

                        return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          future: FirebaseFirestore.instance
                              .collection('beers')
                              .doc(beerId)
                              .get(),
                          builder: (context, beerSnap) {
                            if (!beerSnap.hasData || !beerSnap.data!.exists) {
                              return const SizedBox.shrink();
                            }

                            final beer = beerSnap.data!.data()!;
                            final beerName = (beer['name'] ?? 'Cerveza')
                                .toString();
                            final beerPhoto = (beer['photoUrl'] ?? '')
                                .toString();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                              color: Colors.deepPurple[50],
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    context.push('/beer/detail', extra: beerId),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Cabecera
                                      FutureBuilder<Map<String, dynamic>?>(
                                        future: _loadUserData(actorUid),
                                        builder: (context, userSnap) {
                                          final userData = userSnap.data ?? {};
                                          final actorName =
                                              (userData['username'] ??
                                                      "Usuario")
                                                  .toString();
                                          return Row(
                                            children: [
                                              AvatarUsuario(
                                                userId: actorUid,
                                                radius: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  actorName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                createdAt != null
                                                    ? createdAt
                                                          .toLocal()
                                                          .toString()
                                                          .split(' ')[0]
                                                    : '',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10),

                                      // Cerveza + rating
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage:
                                                beerPhoto.isNotEmpty
                                                ? NetworkImage(beerPhoto)
                                                : const AssetImage(
                                                        'default_avatar.png',
                                                      )
                                                      as ImageProvider,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              "$beerName • $rating ★",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }

                  // Otros tipos de actividad (amistades, etc.)
                  return ListTile(
                    leading: AvatarUsuario(userId: actorUid, radius: 22),
                    title: FutureBuilder<Map<String, dynamic>?>(
                      future: _loadUserData(actorUid),
                      builder: (context, userSnap) {
                        final userData = userSnap.data ?? {};
                        final actorName = (userData['username'] ?? "Usuario")
                            .toString();
                        return Text(
                          actorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    subtitle: Text(
                      "Actividad reciente\n${createdAt?.toLocal().toString().split(' ')[0] ?? ''}",
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
}
