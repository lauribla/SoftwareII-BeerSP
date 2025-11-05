import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:async/async.dart';
import 'BeerDetailScreen.dart';




class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  /// Obtener mis amigos confirmados + mi propio UID
  Future<List<String>> _getFriendsAndMe() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(myUid).get();

    if (!userDoc.exists) return [myUid];

    final data = userDoc.data()!;
    final friends = List<String>.from(data['friends'] ?? []);

    // Incluye mi propio UID para ver mis actividades también
    return [myUid, ...friends];
  }

  /// Cargar actividades de mí + mis amigos
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(
      List<String> uids) {
    // Firestore whereIn tiene límite de 10, lo dividimos en trozos si hace falta
    if (uids.length <= 10) {
      return FirebaseFirestore.instance
          .collection('activities')
          .where('actorUid', whereIn: uids)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();
    }

    // Combinar streams si hay más de 10 amigos
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

    // Mezcla todos los streams en uno
    return StreamGroup.merge(streams);
  }

  /// Cargar favoritos (solo marcados favoritos, últimas 3)
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadFavorites(String uid) {
    return FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  /// Cargar galardones (tuyos)
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadBadges(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  /// Obtener datos de un usuario (username, photoUrl)
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

  /// Mostrar solicitudes entrantes en un modal
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data();
                final requests =
                    List<String>.from(data?['friendRequests'] ?? []);

                if (requests.isEmpty) {
                  return const Center(
                      child: Text("No hay solicitudes pendientes"));
                }

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final requesterUid = requests[index];

                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(requesterUid)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox.shrink();

                        final user = userSnap.data!.data();
                        if (user == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (user['photoUrl'] ?? '').isNotEmpty
                                ? NetworkImage(user['photoUrl'])
                                : null,
                            child: (user['photoUrl'] ?? '').isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(user['username'] ?? 'Usuario'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  await _acceptFriendRequest(
                                      myUid, requesterUid);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Solicitud aceptada")),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  await _rejectFriendRequest(
                                      myUid, requesterUid);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Solicitud rechazada")),
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

  /// Aceptar solicitud
  Future<void> _acceptFriendRequest(String myUid, String otherUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final otherRef =
        FirebaseFirestore.instance.collection('users').doc(otherUid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(myRef, {
        'friends': FieldValue.arrayUnion([otherUid]),
        'friendRequests': FieldValue.arrayRemove([otherUid]),
      });
      tx.update(otherRef, {
        'friends': FieldValue.arrayUnion([myUid]),
      });
    });
  }

  /// Rechazar solicitud
  Future<void> _rejectFriendRequest(String myUid, String otherUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    await myRef.update({
      'friendRequests': FieldValue.arrayRemove([otherUid]),
    });
  }

final List<Map<String, dynamic>> allCervezas = const [
  {'nombre': 'IPA Golden', 'tipo': 'Cerveza'},
  {'nombre': 'Stout Negra', 'tipo': 'Cerveza'},
  {'nombre': 'Amber Ale', 'tipo': 'Cerveza'},
];

final List<Map<String, dynamic>> allLocales = const [
  {'nombre': 'Bar Central', 'tipo': 'Local'},
  {'nombre': 'CervezaLab', 'tipo': 'Local'},
  {'nombre': 'La Fábrica', 'tipo': 'Local'},
];


/// Top degustaciones del usuario actual (3 mejores según rating)
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
            // 🔍 Barra de búsqueda de cervezas y locales
const SearchBarWidget(),
const SizedBox(height: 16),
            // 📋 Resumen del perfil del usuario

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

        
           // ⭐ Top degustaciones del usuario (desde Firestore)
if (uid != null)
  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _loadTopDegustaciones(uid),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Cargando top degustaciones...'),
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Card(
          child: ListTile(
            leading: Icon(Icons.star_border),
            title: Text('Todavía no tienes degustaciones registradas'),
          ),
        );
      }

      final docs = snapshot.data!.docs;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⭐ Top degustaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final doc in docs)
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('beers')
                    .doc(doc['beerId'])
                    .get(),
                builder: (context, beerSnap) {
                  if (beerSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: Icon(Icons.local_drink),
                      title: Text("Cargando cerveza..."),
                    );
                  }

                  if (!beerSnap.hasData || !beerSnap.data!.exists) {
                    return ListTile(
                      leading: const Icon(Icons.error),
                      title: Text(
                          "Cerveza desconocida (${doc['beerId']})"),
                      subtitle: Text(
                          'Valoración: ${doc['rating'] ?? 0} ★'),
                    );
                  }

                  final beer = beerSnap.data!.data()!;
                  final name = beer['name'] ?? 'Desconocida';
                  final style = beer['style'] ?? '—';
                  final photoUrl = beer['photoUrl'] ?? '';
                  final rating = doc['rating'] ?? 0;

                  return Card(
                    child: ListTile(
                      leading: photoUrl.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(photoUrl))
                          : const Icon(Icons.local_drink,
                              color: Colors.brown),
                      title: Text(name),
                      subtitle: Text(style),
                      trailing: Text('$rating ★'),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  ),
const SizedBox(height: 16),


            // Panel de actividades (yo + amigos, últimas 5)
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

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          

            // Panel de galardones
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
              const SizedBox(height: 16),

              // 📋 Mis degustaciones (robusto y simple)
if (uid != null)
  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .snapshots(), // sin orderBy → sin índices compuestos
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Cargando degustaciones...'),
          ),
        );
      }

      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error, color: Colors.red),
            title: Text('Error al cargar degustaciones'),
            subtitle: Text(snapshot.error.toString()),
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Card(
          child: ListTile(
            leading: Icon(Icons.local_drink_outlined),
            title: Text('Aún no has registrado degustaciones'),
          ),
        );
      }

      final degustaciones = snapshot.data!.docs;

      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              title: Text('Mis degustaciones'),
              subtitle: Text('Pulsa la estrella para marcar favoritas'),
            ),
            for (final d in degustaciones)
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('beers')
                    .doc(d['beerId'])
                    .get(),
                builder: (context, beerSnap) {
                  if (beerSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Cargando cerveza...'),
                    );
                  }

                  final beer = beerSnap.data?.data() ?? {};
                  final beerName = beer['name'] ?? 'Cerveza desconocida';
                  final style = beer['style'] ?? '—';
                  final photoUrl = beer['photoUrl'] ?? '';
                  final rating = d.data().containsKey('rating')
                      ? d['rating']
                      : 0;
                  final isFav = d.data().containsKey('isFavorite')
                      ? d['isFavorite']
                      : false;

                  return ListTile(
                    leading: photoUrl.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                        : const Icon(Icons.local_drink, color: Colors.brown),
                    title: Text(beerName),
                    subtitle: Text('$style • $rating ★'),
                    trailing: IconButton(
                      icon: Icon(
                        isFav ? Icons.star : Icons.star_border,
                        color: isFav ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('tastings')
                            .doc(d.id)
                            .update({'isFavorite': !isFav});
                      },
                    ),
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
        tooltip: 'Registrar degustación',
      ),
    );
  }
}

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
        .map((d) => {
              'nombre': d['name'],
              'tipo': 'Cerveza',
              'beerId': d.id,
            });

    final filteredVenues = venuesSnap.docs
        .where((d) => (d['name'] ?? '').toString().toLowerCase().contains(q))
        .map((d) => {
              'nombre': d['name'],
              'tipo': 'Local',
              'venueId': d.id,
            });

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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: results.map((r) {
                return ListTile(
                  leading: Icon(
                    r['tipo'] == 'Cerveza'
                        ? Icons.sports_bar
                        : Icons.location_on,
                    color: Colors.amber[800],
                  ),
                  title: Text(r['nombre']),
                  subtitle: Text(r['tipo']),
                  onTap: () {
                    if (r['tipo'] == 'Cerveza') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BeerDetailScreen(beerId: r['beerId']),
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
