import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:async/async.dart';
import 'BeerDetailScreen.dart';
import 'AvatarUsuario.dart'; // Nuevo import

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Future<List<String>> _getFriendsAndMe() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .get();

    if (!userDoc.exists) return [myUid];

    final data = userDoc.data()!;
    final friends = List<String>.from(data['friends'] ?? []);

    return [myUid, ...friends];
  }

  /// Cargar actividades de mí + mis amigos
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadActivities(
    List<String> uids,
  ) {
    // Firestore whereIn tiene límite de 10, lo dividimos en trozos si hace falta
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
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data();
                final requests = List<String>.from(
                  data?['friendRequests'] ?? [],
                );

                if (requests.isEmpty) {
                  return const Center(
                    child: Text("No hay solicitudes pendientes"),
                  );
                }

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final requesterUid = requests[index];

                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(requesterUid)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox.shrink();

                        final user = userSnap.data!.data();
                        if (user == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: AvatarUsuario(
                            userId: requesterUid,
                            radius: 22,
                          ),
                          title: Text(user['username'] ?? 'Usuario'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  await _acceptFriendRequest(
                                    myUid,
                                    requesterUid,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Solicitud aceptada"),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await _rejectFriendRequest(
                                    myUid,
                                    requesterUid,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Solicitud rechazada"),
                                    ),
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
    final otherRef = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid);

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

  Future<void> _rejectFriendRequest(String myUid, String otherUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    await myRef.update({
      'friendRequests': FieldValue.arrayRemove([otherUid]),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadTopDegustaciones(
    String uid,
  ) {
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
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
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

            // ⭐ Top degustaciones + Galardones (responsive)
            if (uid != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  // ----------- WIDGET TOP DEGUSTACIONES (tu versión mejorada) -------------
                  final topDegustacionesWidget =
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _loadTopDegustaciones(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Card(
                              child: ListTile(
                                leading: CircularProgressIndicator(),
                                title: Text('Cargando top degustaciones...'),
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Card(
                              child: ListTile(
                                leading: Icon(Icons.star_border),
                                title: Text(
                                  'Todavía no tienes degustaciones registradas',
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    title: Text(
                                      '⭐ Top degustaciones',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  for (final doc in docs)
                                    FutureBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
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
                                              "Cerveza desconocida (${doc['beerId']})",
                                            ),
                                            subtitle: Text(
                                              'Valoración: ${doc['rating'] ?? 0} ★',
                                            ),
                                          );
                                        }

                                        final beer = beerSnap.data!.data()!;
                                        final name =
                                            beer['name'] ?? 'Desconocida';
                                        final style = beer['style'] ?? '—';
                                        final photoUrl = beer['photoUrl'] ?? '';
                                        final rating = doc['rating'] ?? 0;

                                        return Card(
                                          child: ListTile(
                                            leading: photoUrl.isNotEmpty
                                                ? CircleAvatar(
                                                    backgroundImage:
                                                        NetworkImage(photoUrl),
                                                  )
                                                : const Icon(
                                                    Icons.local_drink,
                                                    color: Colors.brown,
                                                  ),
                                            title: Text(name),
                                            subtitle: Text(style),
                                            trailing: Text('$rating ★'),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                  // ----------- WIDGET GALARDONES (tu versión) -------------
                  final galardonesWidget =
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _loadBadges(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Card(
                              child: ListTile(
                                leading: CircularProgressIndicator(),
                                title: Text('Cargando galardones...'),
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
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
                                    leading: const Icon(
                                      Icons.emoji_events,
                                      color: Colors.orange,
                                    ),
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
                      );

                  // ----------- RENDER RESPONSIVE -------------
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

            // Actividades de amigos
            if (uid != null)
              FutureBuilder<List<String>>(
                future: _getFriendsAndMe(),
                builder: (context, friendSnap) {
                  if (!friendSnap.hasData) return const SizedBox.shrink();
                  final uids = friendSnap.data!;
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _loadActivities(uids),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Cargando actividades...'),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final docs = snapshot.data!.docs;
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(title: Text('Actividad de amigos')),
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
                                    leading: AvatarUsuario(
                                      userId: doc['actorUid'],
                                      radius: 22,
                                    ),
                                    title: Text(actorName),
                                    subtitle: Text(
                                      "$description\n${createdAt != null ? createdAt.toLocal().toString().split(' ')[0] : 'sin fecha'}",
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 16),

            // Mis degustaciones (robusto y simple)
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
                          subtitle: Text(
                            'Pulsa la estrella para marcar favoritas',
                          ),
                        ),
                        for (final d in degustaciones)
                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('beers')
                                .doc(d['beerId'])
                                .get(),
                            builder: (context, beerSnap) {
                              if (beerSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const ListTile(
                                  leading: CircularProgressIndicator(),
                                  title: Text('Cargando cerveza...'),
                                );
                              }

                              final beer = beerSnap.data?.data() ?? {};
                              final beerName =
                                  beer['name'] ?? 'Cerveza desconocida';
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
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(photoUrl),
                                      )
                                    : const Icon(
                                        Icons.local_drink,
                                        color: Colors.brown,
                                      ),
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
                                onTap: () {
                                  context.push(
                                    '/tasting/detail',
                                    extra: d
                                        .id, // 👈 usamos el ID de la degustación
                                  );
                                },
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

// SearchBarWidget tal como estaba antes, usando Firestore directamente
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  String searchQuery = '';
  List<Map<String, dynamic>> results = [];
  String searchType = 'Cervezas'; // Default selection
  bool showFilters = false;

  // Filter fields
  String? estilo;
  String? color;
  String? tamano;
  String? formato;
  String? pais;
  String? abvInterval;

  final List<String> countryNames = [
    'Afghanistan',
    'Åland Islands',
    'Albania',
    'Algeria',
    'American Samoa',
    'Andorra',
    'Angola',
    'Anguilla',
    'Antigua and Barbuda',
    'Argentina',
    'Armenia',
    'Aruba',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bermuda',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'British Indian Ocean Territory',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Cape Verde',
    'Cayman Islands',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Christmas Island',
    'Cocos (Keeling) Islands',
    'Colombia',
    'Comoros',
    'Democratic Republic Congo',
    'Republic of Congo',
    'Cook Islands',
    'Costa Rica',
    'Côte d\'Ivoire',
    'Croatia',
    'Cuba',
    'Curaçao',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Falkland Islands',
    'Faroe Islands',
    'Fiji',
    'Finland',
    'France',
    'French Guiana',
    'French Polynesia',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Gibraltar',
    'Greece',
    'Greenland',
    'Grenada',
    'Guadeloupe',
    'Guam',
    'Guatemala',
    'Guernsey',
    'Guinea Conakry',
    'Guinea-Bissau',
    'Guyana',
    'Haiti',
    'Honduras',
    'Hong Kong',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Isle of Man',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jersey',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kiribati',
    'Kosovo',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Liechtenstein',
    'Lithuania',
    'Luxembourg',
    'Macau',
    'North Macedonia',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Marshall Islands',
    'Martinique',
    'Mauritania',
    'Mauritius',
    'Mayotte',
    'Mexico',
    'Micronesia',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Montenegro',
    'Montserrat',
    'Morocco',
    'Mozambique',
    'Myanmar [Burma]',
    'Namibia',
    'Nauru',
    'Nepal',
    'Netherlands',
    'New Caledonia',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'Niue',
    'Norfolk Island',
    'North Korea',
    'Northern Mariana Islands',
    'Norway',
    'Oman',
    'Pakistan',
    'Palau',
    'Palestinian Territories',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Puerto Rico',
    'Qatar',
    'Réunion',
    'Romania',
    'Russia',
    'Rwanda',
    'Saint Barthélemy',
    'Saint Helena',
    'St. Kitts',
    'St. Lucia',
    'Saint Martin',
    'Saint Pierre and Miquelon',
    'St. Vincent',
    'Samoa',
    'San Marino',
    'São Tomé and Príncipe',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Seychelles',
    'Sierra Leone',
    'Singapore',
    'Sint Maarten',
    'Slovakia',
    'Slovenia',
    'Solomon Islands',
    'Somalia',
    'South Africa',
    'South Korea',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Svalbard and Jan Mayen',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Togo',
    'Tokelau',
    'Tonga',
    'Trinidad/Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Turks and Caicos Islands',
    'Tuvalu',
    'U.S. Virgin Islands',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Vanuatu',
    'Vatican City',
    'Venezuela',
    'Vietnam',
    'Wallis and Futuna',
    'Western Sahara',
    'Yemen',
    'Zambia',
    'Zimbabwe',
  ];

  Future<void> search(String query) async {
    setState(() {
      searchQuery = query;
      results = [];
    });

    final q = query.toLowerCase();

    if (searchType == 'Cervezas') {
      final beersSnap = await FirebaseFirestore.instance
          .collection('beers')
          .get();

      final filteredBeers = beersSnap.docs
          .where((d) {
            final nameMatch = (d['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q);
            final estiloMatch = estilo == null || d['style'] == estilo;
            final colorMatch = color == null || d['color'] == color;
            final tamanoMatch = tamano == null || d['size'] == tamano;
            final formatoMatch = formato == null || d['format'] == formato;
            final paisMatch = pais == null || d['originCountry'] == pais;
            return nameMatch &&
                estiloMatch &&
                colorMatch &&
                tamanoMatch &&
                formatoMatch &&
                paisMatch;
          })
          .map(
            (d) => {
              'nombre': d['name'],
              'tipo': 'Cerveza',
              'beerId': d.id,
              'photoUrl': d['photoUrl'] ?? '',
            },
          );

      setState(() {
        results = [...filteredBeers];
      });
    } else {
      final venuesSnap = await FirebaseFirestore.instance
          .collection('venues')
          .get();

      final filteredVenues = venuesSnap.docs
          .where((d) {
            final nameMatch = (d['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q);
            final paisMatch = pais == null || d['country'] == pais;
            return nameMatch && paisMatch;
          })
          .map((d) => {'nombre': d['name'], 'tipo': 'Local', 'venueId': d.id});

      setState(() {
        results = [...filteredVenues];
      });
    }
  }

  void _applyFilters() {
    search(searchQuery);
    setState(() => showFilters = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.0,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: searchType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Cervezas',
                        child: Text('Cervezas'),
                      ),
                      DropdownMenuItem(
                        value: 'Locales',
                        child: Text('Locales'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        searchType = value!;
                        // Reset filters when changing type
                        estilo = null;
                        color = null;
                        tamano = null;
                        formato = null;
                        pais = null;
                        abvInterval = null;
                        search(searchQuery);
                      });
                    },
                    style: Theme.of(context).textTheme.bodyMedium,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar ${searchType.toLowerCase()}...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => showFilters = !showFilters),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.filter_alt,
                        color: Color.fromARGB(255, 100, 95, 38),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Filtros',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showFilters)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search results on the left
              Expanded(
                flex: 2,
                child: Column(
                  children: [
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
                            final photoUrl = r['photoUrl'] ?? '';
                            return ListTile(
                              leading:
                                  (r['tipo'] == 'Cerveza' &&
                                      photoUrl.isNotEmpty)
                                  ? CircleAvatar(
                                      radius: 22,
                                      backgroundImage: NetworkImage(photoUrl),
                                    )
                                  : Icon(
                                      r['tipo'] == 'Cerveza'
                                          ? Icons.sports_bar
                                          : Icons.location_on,
                                      color: Colors.amber[800],
                                      size: 28,
                                    ),
                              title: Text(r['nombre']),
                              subtitle: Text(r['tipo']),
                              onTap: () {
                                if (r['tipo'] == 'Cerveza') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BeerDetailScreen(
                                        beerId: r['beerId'],
                                        tastingId: 'preview',
                                      ),
                                    ),
                                  );
                                }
                                // Add navigation for Locales if needed
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Filtros card on the right
              SizedBox(
                width: 286, // Adjust width as needed
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        if (searchType == 'Cervezas') ...[
                          DropdownButtonFormField<String>(
                            value: estilo,
                            decoration: const InputDecoration(
                              labelText: "Estilo",
                              isDense: true,
                            ),
                            items:
                                [
                                      'Lager',
                                      'IPA',
                                      'APA',
                                      'Stout',
                                      'Saison',
                                      'Porter',
                                      'Pilsner',
                                      'Weissbier',
                                      'Sour Ale',
                                      'Lambic',
                                      'Amber Ale',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => estilo = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: color,
                            decoration: const InputDecoration(
                              labelText: "Color",
                              isDense: true,
                            ),
                            items:
                                [
                                      'Dorado claro',
                                      'Amarillo dorado',
                                      'Ambar claro',
                                      'Marrón oscuro',
                                      'Negro opaco',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => color = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: tamano,
                            decoration: const InputDecoration(
                              labelText: "Tamaño",
                              isDense: true,
                            ),
                            items: ['Pinta', 'Media pinta', 'Tercio']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => tamano = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: formato,
                            decoration: const InputDecoration(
                              labelText: "Formato",
                              isDense: true,
                            ),
                            items: ['Barril', 'Lata', 'Botella']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => formato = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: pais,
                            decoration: const InputDecoration(
                              labelText: "Origen",
                              isDense: true,
                            ),
                            items: countryNames
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => pais = v),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: abvInterval,
                            decoration: const InputDecoration(
                              labelText: "Alcohol %",
                              isDense: true,
                            ),
                            items: ['0–3%', '3–5%', '5–7%', '7%+']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => abvInterval = v),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            value: pais,
                            decoration: const InputDecoration(
                              labelText: "País",
                              isDense: true,
                            ),
                            items:
                                [
                                      'España',
                                      'Alemania',
                                      'Bélgica',
                                      'Estados Unidos',
                                      'Reino Unido',
                                      'México',
                                      'Argentina',
                                      'Japón',
                                      'Otro',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => pais = v),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                estilo = null;
                                color = null;
                                tamano = null;
                                formato = null;
                                pais = null;
                                abvInterval = null;
                                showFilters = false;
                                search(searchQuery);
                              }),
                              child: const Text("Limpiar"),
                            ),
                            ElevatedButton(
                              onPressed: _applyFilters,
                              child: const Text("Aplicar filtros"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          // Show only results if filters are hidden
          Column(
            children: [
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
                      final photoUrl = r['photoUrl'] ?? '';
                      return ListTile(
                        leading: (r['tipo'] == 'Cerveza' && photoUrl.isNotEmpty)
                            ? CircleAvatar(
                                radius: 22,
                                backgroundImage: NetworkImage(photoUrl),
                              )
                            : Icon(
                                r['tipo'] == 'Cerveza'
                                    ? Icons.sports_bar
                                    : Icons.location_on,
                                color: Colors.amber[800],
                                size: 28,
                              ),
                        title: Text(r['nombre']),
                        subtitle: Text(r['tipo']),
                        onTap: () {
                          if (r['tipo'] == 'Cerveza') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BeerDetailScreen(
                                  beerId: r['beerId'],
                                  tastingId: 'preview',
                                ),
                              ),
                            );
                          }
                          // Add navigation for Locales if needed
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
