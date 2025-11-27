import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class TastingDetailScreen extends StatelessWidget {
  final String tastingId; // id de la degustación

  const TastingDetailScreen({super.key, required this.tastingId});

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadTasting() {
    return FirebaseFirestore.instance
        .collection('tastings')
        .doc(tastingId)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadComments() {
    return FirebaseFirestore.instance
        .collection('tastings')
        .doc(tastingId)
        .collection('comentarios')
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.deepPurple[50];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de degustación"),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadTasting(),
        builder: (context, snapTasting) {
          if (snapTasting.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapTasting.hasData || !snapTasting.data!.exists) {
            return const Center(child: Text("Degustación no encontrada"));
          }

          final tasting = snapTasting.data!.data()!;
          final beerId = tasting['beerId'] as String?;
          final rating = tasting['rating']?.toString() ?? '—';
          final tastingNote = (tasting['comment'] ?? '').toString();

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: beerId != null
                ? FirebaseFirestore.instance
                      .collection('beers')
                      .doc(beerId)
                      .get()
                : Future.value(null),
            builder: (context, snapBeer) {
              final beer =
                  (snapBeer.hasData &&
                      snapBeer.data != null &&
                      snapBeer.data!.exists)
                  ? snapBeer.data!.data()
                  : null;

              final photoUrl = beer?['photoUrl'] ?? '';
              final name = beer?['name'] ?? 'Cerveza desconocida';
              final style = beer?['style'] ?? '—';
              final origin = beer?['originCountry'] ?? '—';
              final abv = beer?['abv']?.toString() ?? '—';
              final ibu = beer?['ibu']?.toString() ?? '—';
              final description = beer?['description'] ?? 'Sin descripción';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Foto cerveza
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.local_drink, size: 100),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Título cerveza
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Estilo: $style"),
                    Text("Origen: $origin"),
                    Text("ABV: $abv%"),
                    Text("IBU: $ibu"),
                    const SizedBox(height: 20),

                    // Descripción
                    const Text(
                      "Descripción",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(description),
                    const SizedBox(height: 20),

                    // Card Degustación (rating + nota del autor)
                    Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.sports_bar, size: 22),
                              SizedBox(width: 6),
                              Text(
                                "Degustación",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Valoración: $rating ★",
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (tastingNote.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("Comentario: $tastingNote"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Comentarios (solo lectura)
                    Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.chat_bubble_outline_rounded, size: 20),
                              SizedBox(width: 6),
                              Text(
                                "Comentarios",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _loadComments(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: LinearProgressIndicator(),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Text(
                                  "Todavía no hay comentarios sobre esta degustación 🍻",
                                  style: TextStyle(color: Colors.black54),
                                );
                              }

                              return Column(
                                children: docs.map((doc) {
                                  final c = doc.data();
                                  final nombre = c['nombreAutor'] ?? 'Anónimo';
                                  final texto = c['texto'] ?? '';
                                  final foto = (c['fotoAutor'] ?? '')
                                      .toString();

                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: foto.isNotEmpty
                                              ? NetworkImage(foto)
                                              : const AssetImage(
                                                      'assets/default_avatar.png',
                                                    )
                                                    as ImageProvider,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombre,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                texto,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
