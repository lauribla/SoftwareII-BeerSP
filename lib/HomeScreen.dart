import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  /// 🔑 Obtener mis amigos confirmados + mi propio UID
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

  /// 📡 Cargar actividades de mí + mis amigos
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(
      List<String> uids) {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('actorUid', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  /// 📡 Cargar favoritos (solo marcados ⭐, últimas 3)
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadFavorites(String uid) {
    return FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  /// 📡 Cargar galardones (tuyos)
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadBadges(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  /// 📡 Obtener datos de un usuario (username, photoUrl)
  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/auth'); // vuelve al login/registro
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
  title: const Text('BeerSp - Inicio'),
  actions: [
    IconButton(
      icon: const Icon(Icons.group),
      tooltip: "Amigos",
      onPressed: () => context.go('/friends'),
    ),
    IconButton(
      icon: const Icon(Icons.person),
      tooltip: "Editar perfil",
      onPressed: () => context.go('/profile'),
    ),
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => _signOut(context),
      tooltip: 'Cerrar sesión',
    ),
  ],
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 👤 Panel de perfil resumido
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: _loadUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Cargando perfil...'),
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Card(
                    child: ListTile(
                      leading: Icon(Icons.error),
                      title: Text('No se encontró el perfil'),
                    ),
                  );
                }

                final data = snapshot.data!.data()!;
                final username = data['username'] ?? 'Usuario';
                final photoUrl = data['photoUrl'] ?? '';
                final stats = data['stats'] ?? {};
                final tastings = stats['tastingsTotal'] ?? 0;
                final venues = stats['venuesTotal'] ?? 0;
                final badges = stats['badgesCount'] ?? 0;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(username),
                    subtitle: Text(
                      'Total: $tastings degustaciones, $venues locales, $badges galardones',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 📜 Panel de actividades (yo + amigos, últimas 5)
            if (uid != null)
              FutureBuilder<List<String>>(
                future: _getFriendsAndMe(),
                builder: (context, friendSnap) {
                  if (friendSnap.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Cargando actividades...'),
                      ),
                    );
                  }

                  if (!friendSnap.hasData || friendSnap.data!.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.history),
                        title: Text('No hay actividades aún'),
                      ),
                    );
                  }

                  final uids = friendSnap.data!;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _loadActivities(uids),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Card(
                          child: ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Cargando actividades...'),
                          ),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text('No hay actividades aún'),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(
                              title: Text('Actividad'),
                              subtitle: Text('Tú y tus amigos'),
                            ),
                            for (final doc in docs)
                              FutureBuilder<Map<String, dynamic>?>(
                                future: _loadUserData(doc['actorUid']),
                                builder: (context, userSnap) {
                                  final userData = userSnap.data ?? {};
                                  final actorName =
                                      userData['username'] ?? "Usuario";
                                  final actorPhotoUrl =
                                      userData['photoUrl'] ?? "";

                                  final createdAt =
                                      (doc['createdAt'] as Timestamp?)
                                          ?.toDate();
                                  final type = doc['type'] ?? 'actividad';

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

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          actorPhotoUrl.isNotEmpty
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
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  context.go('/activities');
                                },
                                child: const Text('Ver todas'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

            const SizedBox(height: 16),

            // ⭐ Panel de cervezas favoritas (últimas 3)
            if (uid != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _loadFavorites(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Cargando favoritas...'),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.star_border),
                        title: Text('Todavía no tienes cervezas favoritas'),
                      ),
                    );
                  }

                  final tastings = snapshot.data!.docs;

                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          title: Text('Cervezas favoritas'),
                          subtitle: Text('Últimas 3 favoritas'),
                        ),
                        for (final doc in tastings)
                          FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('beers')
                                .doc(doc['beerId'])
                                .get(),
                            builder: (context, beerSnap) {
                              if (beerSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const ListTile(
                                  leading: Icon(Icons.local_drink),
                                  title: Text("Cargando cerveza..."),
                                );
                              }

                              if (!beerSnap.hasData ||
                                  !beerSnap.data!.exists) {
                                return ListTile(
                                  leading: const Icon(Icons.error),
                                  title: Text(
                                      "Cerveza desconocida (${doc['beerId']})"),
                                  subtitle: Text(
                                      'Valoración: ${doc['rating']} ⭐'),
                                );
                              }

                              final beer = beerSnap.data!.data()!;
                              final name = beer['name'] ?? 'Desconocida';
                              final style = beer['style'] ?? '—';
                              final photoUrl = beer['photoUrl'] ?? '';
                              final rating = doc['rating'] ?? 0;

                              return ListTile(
                                leading: photoUrl.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage:
                                            NetworkImage(photoUrl))
                                    : const Icon(Icons.local_drink,
                                        color: Colors.brown),
                                title: Text(name),
                                subtitle: Text(style),
                                trailing: Text('$rating ⭐'),
                                onTap: () =>
                                    context.go('/beer/${doc['beerId']}'),
                              );
                            },
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              context.go('/tastings/top');
                            },
                            child: const Text('Ver todas'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // 🏆 Panel de galardones
            if (uid != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _loadBadges(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Cargando galardones...'),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.emoji_events_outlined),
                        title: Text('Todavía no tienes galardones'),
                      ),
                    );
                  }

                  final badges = snapshot.data!.docs;

                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          title: Text('Últimos galardones'),
                          subtitle: Text('Máx. 5 recientes'),
                        ),
                        for (final doc in badges)
                          ListTile(
                            leading: const Icon(Icons.emoji_events,
                                color: Colors.orange),
                            title: Text('Galardón: ${doc.id}'),
                            subtitle: Text('Nivel: ${doc['level']}'),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              context.go('/badges');
                            },
                            child: const Text('Ver todos'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tastings/new'),
        child: const Icon(Icons.add),
        tooltip: 'Registrar degustación',
      ),
    );
  }
}
