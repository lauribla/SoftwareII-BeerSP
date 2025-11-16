import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:async/async.dart';
import 'BeerDetailScreen.dart';
import 'AvatarUsuario.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<List<String>> _getFriendsAndMe() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    if (!userDoc.exists) return [myUid];
    final data = userDoc.data()!;
    final friends = List<String>.from(data['friends'] ?? []);
    return [myUid, ...friends];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(List<String> uids) {
    if (uids.length <= 10) {
      return FirebaseFirestore.instance
          .collection('activities')
          .where('actorUid', whereIn: uids)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();
    }

    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
    }

    final streams = chunks.map((chunk) {
      return FirebaseFirestore.instance
          .collection('activities')
          .where('actorUid', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();
    });

    return StreamGroup.merge(streams);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadFavorites(String uid) {
    return FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadBadges(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/auth');
    }
  }

  void _showFriendRequests(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final data = snapshot.data!.data();
                final requests = List<String>.from(data?['friendRequests'] ?? []);

                if (requests.isEmpty) {
                  return const Center(child: Text("No hay solicitudes pendientes"));
                }

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final requesterUid = requests[index];

                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('users').doc(requesterUid).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || userSnap.data == null) return const SizedBox.shrink();
                        final user = userSnap.data!.data()!;
                        return ListTile(
                          leading: AvatarUsuario(userId: requesterUid, radius: 22),
                          title: Text(user['username'] ?? 'Usuario'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  await _acceptFriendRequest(myUid, requesterUid);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Solicitud aceptada")),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  await _rejectFriendRequest(myUid, requesterUid);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Solicitud rechazada")),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _acceptFriendRequest(String myUid, String otherUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final otherRef = FirebaseFirestore.instance.collection('users').doc(otherUid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(myRef, {
        'friends': FieldValue.arrayUnion([otherUid]),
        'friendRequests': FieldValue.arrayRemove([otherUid]),
      });
      tx.update(otherRef, {'friends': FieldValue.arrayUnion([myUid])});
    });
  }

  Future<void> _rejectFriendRequest(String myUid, String otherUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    await myRef.update({'friendRequests': FieldValue.arrayRemove([otherUid])});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadTopDegustaciones(String uid) {
    return FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .orderBy('rating', descending: true)
        .limit(3)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BeerSp - Inicio'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: "Solicitudes de amistad",
            onPressed: () => _showFriendRequests(context),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: "Amigos",
            onPressed: () => context.go('/friends'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Ajustes",
            onPressed: () => context.go('/profile'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SearchBarWidget(),
            const SizedBox(height: 16),

            // Perfil del usuario
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
                final stats = data['stats'] ?? {};
                final tastings = stats['tastingsTotal'] ?? 0;
                final venues = stats['venuesTotal'] ?? 0;
                final badges = stats['badgesCount'] ?? 0;

                return Card(
                  child: ListTile(
                    leading: const AvatarUsuario(radius: 24),
                    title: Text(username),
                    subtitle: Text(
                      'Total: $tastings degustaciones, $venues locales, $badges galardones',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Top degustaciones + Galardones
            if (uid != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final topDegustacionesWidget =
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _loadTopDegustaciones(uid),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(title: Text('⭐ Top degustaciones')),
                            if (docs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('No hay degustaciones')),
                              ),
                            for (final doc in docs)
                              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance
                                    .collection('beers')
                                    .doc(doc['beerId'])
                                    .get(),
                                builder: (context, beerSnap) {
                                  if (!beerSnap.hasData || !beerSnap.data!.exists) {
                                    return const SizedBox.shrink();
                                  }
                                  final beer = beerSnap.data!.data()!;
                                  return ListTile(
                                    title: Text(beer['name'] ?? 'Desconocida'),
                                    subtitle: Text(beer['style'] ?? '—'),
                                    trailing: Text('${doc['rating'] ?? 0} ★'),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );

                  final galardonesWidget =
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _loadBadges(uid),
                    builder: (context, snapshot) {
                      final badges = snapshot.data?.docs ?? [];
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(title: Text('Últimos galardones')),
                            if (badges.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('No hay galardones')),
                              ),
                            for (final doc in badges)
                              ListTile(
                                title: Text('Galardón: ${doc.id}'),
                                subtitle: Text('Nivel: ${doc['level']}'),
                              ),
                          ],
                        ),
                      );
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        topDegustacionesWidget,
                        const SizedBox(height: 16),
                        galardonesWidget,
                      ],
                    );
                  } else {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: topDegustacionesWidget),
                          const SizedBox(width: 16),
                          Expanded(child: galardonesWidget),
                        ],
                      ),
                    );
                  }
                },
              ),

            const SizedBox(height: 16),

            // Mis degustaciones
            if (uid != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('tastings')
                    .where('userUid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                  final degustaciones = snapshot.data!.docs;
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(title: Text('Mis degustaciones')),
                        for (final d in degustaciones)
                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance.collection('beers').doc(d['beerId']).get(),
                            builder: (context, beerSnap) {
                              if (!beerSnap.hasData || !beerSnap.data!.exists) return const SizedBox.shrink();
                              final beer = beerSnap.data!.data()!;
                              return ListTile(
                                title: Text(beer['name'] ?? 'Desconocida'),
                                subtitle: Text(beer['style'] ?? '—'),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tastings/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// SearchBarWidget tal como estaba antes
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  String searchQuery = '';
  List<Map<String, dynamic>> results = [];

  Future<void> search(String query) async {
    setState(() {
      searchQuery = query;
      results = [];
    });

    if (query.trim().isEmpty) return;

    final q = query.toLowerCase();

    final beersSnap = await FirebaseFirestore.instance.collection('beers').get();
    final venuesSnap = await FirebaseFirestore.instance.collection('venues').get();

    final filteredBeers = beersSnap.docs
        .where((d) => (d['name'] ?? '').toString().toLowerCase().contains(q))
        .map((d) => {'nombre': d['name'], 'tipo': 'Cerveza', 'beerId': d.id});

    final filteredVenues = venuesSnap.docs
        .where((d) => (d['name'] ?? '').toString().toLowerCase().contains(q))
        .map((d) => {'nombre': d['name'], 'tipo': 'Local', 'venueId': d.id});

    setState(() {
      results = [...filteredBeers, ...filteredVenues];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar cervezas o locales...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        if (searchQuery.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
              ],
            ),
            child: Column(
              children: results.map((r) {
                return ListTile(
                  leading: Icon(
                    r['tipo'] == 'Cerveza' ? Icons.sports_bar : Icons.location_on,
                    color: Colors.amber[800],
                  ),
                  title: Text(r['nombre']),
                  subtitle: Text(r['tipo']),
                  onTap: () {
                    if (r['tipo'] == 'Cerveza') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BeerDetailScreen(beerId: r['beerId']),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
