import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BeerDetailScreen extends StatefulWidget {
  final String beerId;
  final String tastingId; // 'preview' cuando vienes desde la búsqueda

  const BeerDetailScreen({
    super.key,
    required this.beerId,
    required this.tastingId,
  });

  @override
  State<BeerDetailScreen> createState() => _BeerDetailScreenState();
}

class _BeerDetailScreenState extends State<BeerDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadBeer() {
    return FirebaseFirestore.instance
        .collection('beers')
        .doc(widget.beerId)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _favoriteStream(String uid) {
    return FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', isEqualTo: uid)
        .where('beerId', isEqualTo: widget.beerId)
        .where('isFavorite', isEqualTo: true)
        .limit(1)
        .snapshots();
  }

  Future<void> _toggleFavorite(String uid, bool isFav) async {
    final tastingsRef = FirebaseFirestore.instance.collection('tastings');
    if (isFav) {
      final snap = await tastingsRef
          .where('userUid', isEqualTo: uid)
          .where('beerId', isEqualTo: widget.beerId)
          .where('isFavorite', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'isFavorite': false});
      }
    } else {
      final snap = await tastingsRef
          .where('userUid', isEqualTo: uid)
          .where('beerId', isEqualTo: widget.beerId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({'isFavorite': true});
      } else {
        await tastingsRef.add({
          'userUid': uid,
          'beerId': widget.beerId,
          'isFavorite': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Carga los comentarios de TODAS las degustaciones de esta cerveza
  Future<List<Map<String, dynamic>>> _loadAllCommentsForBeer() async {
    final tastingsSnap = await FirebaseFirestore.instance
        .collection('tastings')
        .where('beerId', isEqualTo: widget.beerId)
        .get();

    final List<Map<String, dynamic>> grouped = [];

    for (final tastingDoc in tastingsSnap.docs) {
      final tastingId = tastingDoc.id;
      final tasting = tastingDoc.data();

      final rating = tasting['rating'];
      final userUid = tasting['userUid'];
      final venueId = tasting['venueId'];
      final createdAt = tasting['createdAt'];

      // Usuario
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();
      final userData = userSnap.data() ?? {};

      final tastingUserName = userData['username'] ?? 'Usuario';
      final tastingUserPhoto =
          userData['fotoPerfil'] ?? userData['photoUrl'] ?? '';

      // Local
      String venueName = '—';
      if (venueId != null) {
        final venueSnap = await FirebaseFirestore.instance
            .collection('venues')
            .doc(venueId)
            .get();
        if (venueSnap.exists) {
          venueName = venueSnap.data()?['name'] ?? '—';
        }
      }

      // Comentarios de esta degustación
      final commentsSnap = await tastingDoc.reference
          .collection('comentarios')
          .orderBy('fecha')
          .get();

      if (commentsSnap.docs.isEmpty) continue;

      final comments = commentsSnap.docs.map((c) {
        final d = c.data();
        return {
          'text': d['texto'],
          'authorName': d['nombreAutor'],
          'authorPhoto': d['fotoAutor'],
          'date': d['fecha'],
        };
      }).toList();

      grouped.add({
        'tastingId': tastingId,
        'tastingUserName': tastingUserName,
        'tastingUserPhoto': tastingUserPhoto,
        'tastingCreatedAt': createdAt,
        'tastingRating': rating,
        'venueName': venueName,
        'comments': comments,
      });
    }

    // Ordenar por fecha de creación de la degustación (más reciente arriba)
    grouped.sort((a, b) {
      final fa = a['tastingCreatedAt'];
      final fb = b['tastingCreatedAt'];
      if (fa == null || fb == null) return 0;
      return (fb as Timestamp).compareTo(fa as Timestamp);
    });

    return grouped;
  }

  /// Comentarios de la degustación (o agregados si es vista previa desde búsqueda)
  Widget _buildCommentsSection() {
    final isPreview = widget.tastingId == 'preview';

    if (!isPreview) {
      // Caso degustación concreta → comentarios normales (sin cambios)
      final commentsStream = FirebaseFirestore.instance
          .collection('tastings')
          .doc(widget.tastingId)
          .collection('comentarios')
          .orderBy('fecha')
          .snapshots();

      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 230, 227, 210),
          borderRadius: BorderRadius.circular(20),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: commentsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text(
                'No hay comentarios todavía. ¡Sé el primero en opinar! 🍺',
                style: TextStyle(color: Colors.black54),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: docs.map((doc) {
                final c = doc.data() as Map<String, dynamic>;
                return _CommentTile(
                  nombreAutor: c['nombreAutor'] ?? 'Anónimo',
                  fotoAutor: (c['fotoAutor'] ?? '').toString(),
                  texto: c['texto'] ?? '',
                );
              }).toList(),
            );
          },
        ),
      );
    }

    // Caso preview → comentarios agregados de TODAS las degustaciones
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 230, 227, 210),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadAllCommentsForBeer(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final comentarios = snap.data!;
          if (comentarios.isEmpty) {
            return const Text(
              'Esta cerveza aún no tiene comentarios en degustaciones',
              style: TextStyle(color: Colors.black54),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: Colors.black87,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Comentarios en degustaciones de esta cerveza',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...comentarios.map((tasting) {
                final comments = tasting['comments'] as List;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CABECERA DE LA DEGUSTACIÓN
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage:
                                (tasting['tastingUserPhoto'] ?? '')
                                    .toString()
                                    .isNotEmpty
                                ? NetworkImage(tasting['tastingUserPhoto'])
                                : const AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tasting['tastingUserName'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  tasting['venueName'],
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                // 👉 FECHA FORMATEADA DE LA DEGUSTACIÓN
                                if (tasting['tastingCreatedAt'] != null)
                                  Text(
                                    (() {
                                      final date =
                                          (tasting['tastingCreatedAt']
                                                  as Timestamp)
                                              .toDate();
                                      final day = date.day.toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      final month = date.month
                                          .toString()
                                          .padLeft(2, '0');
                                      final year = date.year.toString();
                                      return "$day/$month/$year";
                                    })(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${tasting['tastingRating']} ★',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // COMENTARIOS
                      ...comments.map((com) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 40, bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage:
                                    (com['authorPhoto'] ?? '')
                                        .toString()
                                        .isNotEmpty
                                    ? NetworkImage(com['authorPhoto'])
                                    : const AssetImage(
                                            'assets/default_avatar.png',
                                          )
                                          as ImageProvider,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      com['authorName'] ?? 'Anónimo',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(com['text']),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de cerveza"),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _favoriteStream(uid),
            builder: (context, snapshot) {
              final isFav = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : Colors.white,
                ),
                onPressed: () => _toggleFavorite(uid, isFav),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadBeer(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Cerveza no encontrada"));
          }

          final beer = snapshot.data!.data()!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imagen oficial de la cerveza (mismo comportamiento que TastingDetailScreen)
                if (beer['photoUrl'] != null &&
                    beer['photoUrl'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 360,
                              maxHeight: 460,
                            ),
                            child: Image.network(
                              beer['photoUrl'],
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 120,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  beer['name'] ?? 'Desconocida',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text("Estilo: ${beer['style'] ?? '—'}"),
                Text("Origen: ${beer['originCountry'] ?? '—'}"),
                Text("ABV: ${beer['abv']?.toString() ?? '—'}%"),
                Text("IBU: ${beer['ibu']?.toString() ?? '—'}"),
                const SizedBox(height: 20),
                const Text(
                  "Descripción",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(beer['description'] ?? 'Sin descripción'),
                _buildCommentsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Pequeño widget para renderizar cada comentario.
class _CommentTile extends StatelessWidget {
  final String nombreAutor;
  final String fotoAutor;
  final String texto;

  const _CommentTile({
    required this.nombreAutor,
    required this.fotoAutor,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: (fotoAutor.isNotEmpty)
                ? NetworkImage(fotoAutor)
                : const AssetImage('assets/default_avatar.png')
                      as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreAutor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(texto, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
