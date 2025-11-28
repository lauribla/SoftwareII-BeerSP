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

  /// Carga todos los comentarios de TODAS las degustaciones de esta cerveza.
  Future<List<Map<String, dynamic>>> _loadAllCommentsForBeer() async {
    final qsTastings = await FirebaseFirestore.instance
        .collection('tastings')
        .where('beerId', isEqualTo: widget.beerId)
        .get();

    final List<Map<String, dynamic>> all = [];
    for (final t in qsTastings.docs) {
      final qsComments = await t.reference
          .collection('comentarios')
          .orderBy('fecha', descending: false)
          .get();

      for (final c in qsComments.docs) {
        final data = c.data();
        all.add({
          'nombreAutor': data['nombreAutor'] ?? 'Anónimo',
          'fotoAutor': (data['fotoAutor'] ?? '').toString(),
          'texto': data['texto'] ?? '',
          'fecha': data['fecha'],
        });
      }
    }

    // Ordena por fecha si existe
    all.sort((a, b) {
      final fa = a['fecha'];
      final fb = b['fecha'];
      if (fa == null && fb == null) return 0;
      if (fa == null) return -1;
      if (fb == null) return 1;
      return (fa as Timestamp).compareTo(fb as Timestamp);
    });

    return all;
  }

  /// Comentarios de la degustación (o agregados si es vista previa desde búsqueda)
  Widget _buildCommentsSection() {
    final isPreview = widget.tastingId == 'preview';

    Widget commentsList;
    if (isPreview) {
      // Agrega comentarios de todas las degustaciones de esta cerveza
      commentsList = FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadAllCommentsForBeer(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final comentarios = snap.data ?? [];
          if (comentarios.isEmpty) {
            return const Text(
              'Esta cerveza aún no tiene comentarios 🍺',
              style: TextStyle(color: Colors.black54),
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(comentarios.length),
              children: comentarios
                  .map(
                    (c) => _CommentTile(
                      nombreAutor: c['nombreAutor'] ?? 'Anónimo',
                      fotoAutor: (c['fotoAutor'] ?? '').toString(),
                      texto: c['texto'] ?? '',
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );
    } else {
      // Comentarios de la degustación concreta (tiempo real)
      final commentsStream = FirebaseFirestore.instance
          .collection('tastings')
          .doc(widget.tastingId)
          .collection('comentarios')
          .orderBy('fecha', descending: false)
          .snapshots();

      commentsList = StreamBuilder<QuerySnapshot>(
        stream: commentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final comentarios = snapshot.data?.docs ?? [];
          if (comentarios.isEmpty) {
            return const Text(
              'No hay comentarios todavía. ¡Sé el primero en opinar! 🍺',
              style: TextStyle(color: Colors.black54),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(comentarios.length),
              children: comentarios.map((doc) {
                final c = doc.data() as Map<String, dynamic>;
                return _CommentTile(
                  nombreAutor: c['nombreAutor'] ?? 'Anónimo',
                  fotoAutor: (c['fotoAutor'] ?? '').toString(),
                  texto: c['texto'] ?? '',
                );
              }).toList(),
            ),
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPreview
                ? '💬 Comentarios de esta cerveza'
                : '💬 Comentarios de esta degustación',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          commentsList,
          const Divider(height: 20, thickness: 1, color: Colors.deepPurple),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Escribe un comentario...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () async {
                    final texto = _commentController.text.trim();
                    if (texto.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El comentario está vacío 🍺'),
                        ),
                      );
                      return;
                    }

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      // Datos del usuario
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();
                      final userData = userDoc.data() ?? {};

                      final nombreAutor = _firstNonEmpty([
                        userData['username'],
                        user.displayName,
                        user.email,
                        'Anónimo',
                      ]);

                      final fotoAutor = _firstNonEmpty([
                        userData['photoUrl'],
                        userData['fotoPerfil'],
                        user.photoURL,
                      ]);

                      // Dónde guardar el comentario
                      String tastingTargetId = widget.tastingId;

                      if (tastingTargetId == 'preview') {
                        // Reutiliza una degustación del usuario si existe, si no, crea
                        final myTastings = await FirebaseFirestore.instance
                            .collection('tastings')
                            .where('userUid', isEqualTo: user.uid)
                            .where('beerId', isEqualTo: widget.beerId)
                            .limit(1)
                            .get();

                        if (myTastings.docs.isNotEmpty) {
                          tastingTargetId = myTastings.docs.first.id;
                        } else {
                          final newTastingRef = await FirebaseFirestore.instance
                              .collection('tastings')
                              .add({
                                'userUid': user.uid,
                                'beerId': widget.beerId,
                                'createdAt': FieldValue.serverTimestamp(),
                                'rating': 0,
                                'comment': '',
                              });
                          tastingTargetId = newTastingRef.id;
                        }
                      }

                      // Guardar comentario
                      await FirebaseFirestore.instance
                          .collection('tastings')
                          .doc(tastingTargetId)
                          .collection('comentarios')
                          .add({
                            'beerId':
                                widget.beerId, // útil para futuras consultas
                            'autorId': user.uid,
                            'nombreAutor': nombreAutor,
                            'fotoAutor': fotoAutor,
                            'texto': texto,
                            'fecha': FieldValue.serverTimestamp(),
                          });

                      _commentController.clear();
                      FocusScope.of(context).unfocus();

                      if (widget.tastingId == 'preview') {
                        // Refresca la Future de comentarios agregados
                        setState(() {});
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comentario publicado 🍻'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al publicar: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
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
                if ((beer['photoUrl'] ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      beer['photoUrl'],
                      height: 200,
                      fit: BoxFit.cover,
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
