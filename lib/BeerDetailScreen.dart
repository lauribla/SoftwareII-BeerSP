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
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadBeer() {
    return FirebaseFirestore.instance.collection('beers').doc(widget.beerId).get();
  }

  /// 🔑 comprobar si esta cerveza está marcada como favorita por el usuario actual
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
      // quitar de favoritos → poner isFavorite = false en sus tastings
      final snap = await tastingsRef
          .where('userUid', isEqualTo: uid)
          .where('beerId', isEqualTo: widget.beerId)
          .where('isFavorite', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        await doc.reference.update({'isFavorite': false});
      }
    } else {
      // añadir a favoritos → marcar el último tasting como favorito
      final snap = await tastingsRef
          .where('userUid', isEqualTo: uid)
          .where('beerId', isEqualTo: widget.beerId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({'isFavorite': true});
      } else {
        // si no hay tasting aún → crear uno vacío marcado como favorito
        await tastingsRef.add({
          'userUid': uid,
          'beerId': widget.beerId,
          'isFavorite': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de cerveza"),
        leading: BackButton(onPressed: () => context.go('/')),
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
                tooltip: isFav ? "Quitar de favoritas" : "Marcar como favorita",
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
            return const Center(
              child: Text("Cerveza no encontrada"),
            );
          }

          final beer = snapshot.data!.data()!;
          final name = beer['name'] ?? 'Desconocida';
          final style = beer['style'] ?? '—';
          final origin = beer['originCountry'] ?? '—';
          final abv = beer['abv']?.toString() ?? '—';
          final ibu = beer['ibu']?.toString() ?? '—';
          final description = beer['description'] ?? 'Sin descripción';
          final photoUrl = beer['photoUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
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
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text("Estilo: $style"),
                Text("Origen: $origin"),
                Text("ABV: $abv%"),
                Text("IBU: $ibu"),

                const SizedBox(height: 20),
                const Text(
                  "Descripción",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(description),
              ],
            ),
          );
        },
      ),
    );
  }
}
