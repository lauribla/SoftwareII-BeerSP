import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DegustacionesAmigosScreen extends StatelessWidget {
  const DegustacionesAmigosScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _getDegustaciones() async* {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final amigos = List<String>.from(userDoc.data()?['amigos'] ?? []);
    final ids = [user.uid, ...amigos];

    if (ids.isEmpty) {
      yield* const Stream.empty();
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('tastings')
        .where('userUid', whereIn: ids)
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Degustaciones de amigos"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getDegustaciones(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay degustaciones recientes"));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: data['photoUrl'] != null
                      ? Image.network(
                          data['photoUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.local_drink, size: 40),
                  title: Text(data['beerName'] ?? 'Sin nombre'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['authorName'] != null)
                        Text(
                          data['authorName'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      Text(
                        "Valoración: ${data['rating']?.toStringAsFixed(1) ?? '0.0'} ⭐",
                      ),
                      if (data['comment'] != null)
                        Text(
                          data['comment'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  onTap: () => context.push('/degustacion/${docs[index].id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
