import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class BeerDetailScreen extends StatefulWidget {
  final String beerId;

  const BeerDetailScreen({super.key, required this.beerId});

  @override
  State<BeerDetailScreen> createState() => _BeerDetailScreenState();
}

class _BeerDetailScreenState extends State<BeerDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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

  Widget _buildCommentsSection() {
    final commentsStream = FirebaseFirestore.instance
        .collection('beers')
        .doc(widget.beerId)
        .collection('comentarios')
        // 🔧 usamos 'fecha' tal como está en Firestore
        .orderBy('fecha', descending: false)
        .snapshots();

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
          const Text(
            '💬 Comentarios',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
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

              if (!snapshot.hasData) {
                return const Text(
                  'No hay comentarios todavía. ¡Sé el primero en opinar! 🍺',
                  style: TextStyle(color: Colors.black54),
                );
              }

              final comentarios = snapshot.data!.docs;

              if (comentarios.isEmpty) {
                return const Text(
                  'No hay comentarios todavía. ¡Sé el primero en opinar! 🍺',
                  style: TextStyle(color: Colors.black54),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ListView.builder(
                  key: ValueKey(comentarios.length),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comentarios.length,
                  itemBuilder: (context, i) {
                    final c = comentarios[i].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                            backgroundImage:
                                (c['fotoAutor'] != null &&
                                    (c['fotoAutor'] as String).isNotEmpty)
                                ? NetworkImage(c['fotoAutor'])
                                : const AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['nombreAutor'] ?? 'Anónimo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c['texto'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
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
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debes iniciar sesión')),
                        );
                        return;
                      }

                      // 👇 Siempre tomamos nombre/foto desde Firestore (/users/{uid})
                      final snap = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();
                      final u = snap.data() ?? {};

                      final nombreAutor = (u['username'] as String?)?.trim();
                      final fotoAutor = (u['photoUrl'] as String?)?.trim();

                      await FirebaseFirestore.instance
                          .collection('beers')
                          .doc(widget.beerId)
                          .collection('comentarios')
                          .add({
                            'autorId': user.uid,
                            // Fallbacks coherentes si no hay username/foto
                            'nombreAutor':
                                (nombreAutor != null && nombreAutor.isNotEmpty)
                                ? nombreAutor
                                : (user.email ?? 'Anónimo'),
                            'fotoAutor':
                                (fotoAutor != null && fotoAutor.isNotEmpty)
                                ? fotoAutor
                                : '',
                            'texto': texto,
                            'fecha':
                                FieldValue.serverTimestamp(), // 🔐 el ordenBy usa este campo
                          });

                      _commentController.clear();
                      FocusScope.of(context).unfocus();
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
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
                  )
                else
                  Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.local_drink, size: 100),
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
