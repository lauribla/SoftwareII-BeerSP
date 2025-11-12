import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TastingDetailScreen extends StatelessWidget {
  final String beerId; // id de la cerveza asociada a la degustación

  const TastingDetailScreen({super.key, required this.beerId});

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadBeer() {
    return FirebaseFirestore.instance.collection('beers').doc(beerId).get();
  }

  /// Cargar todos los comentarios asociados a esta cerveza (solo lectura)
  Stream<QuerySnapshot<Map<String, dynamic>>> _loadComments() {
    return FirebaseFirestore.instance
        .collection('beers')
        .doc(beerId)
        .collection('comentarios')
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de degustación"),
        leading: BackButton(onPressed: () => context.pop()),
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
          final photoUrl = beer['photoUrl'] ?? '';
          final name = beer['name'] ?? 'Desconocida';
          final style = beer['style'] ?? '—';
          final origin = beer['originCountry'] ?? '—';
          final abv = beer['abv']?.toString() ?? '—';
          final ibu = beer['ibu']?.toString() ?? '—';
          final description = beer['description'] ?? 'Sin descripción';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.local_drink, size: 100),
                  ),
                const SizedBox(height: 20),
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
                const Text(
                  "Descripción",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(description),
                const SizedBox(height: 20),

                // 🔹 Sección de comentarios (solo lectura)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "💬 Comentarios",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _loadComments(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Text(
                              "Todavía no hay comentarios sobre esta cerveza 🍺",
                              style: TextStyle(color: Colors.black54),
                            );
                          }

                          final comentarios = snapshot.data!.docs;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comentarios.length,
                            itemBuilder: (context, index) {
                              final c = comentarios[index].data();
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
                                              (c['fotoAutor'] as String)
                                                  .isNotEmpty)
                                          ? NetworkImage(c['fotoAutor'])
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
                                            c['nombreAutor'] ?? 'Anónimo',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            c['texto'] ?? '',
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
                            },
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
      ),
    );
  }
}
