import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class TopDegustacionesScreen extends StatelessWidget {
  const TopDegustacionesScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadTopBeers() {
    return FirebaseFirestore.instance
        .collection('tastings')
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Top degustaciones"),
        leading: BackButton(onPressed: () => context.go('/')), 
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadTopBeers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Todavía no hay degustaciones"));
          }

          final docs = snapshot.data!.docs;

          return ListView(
            children: [
              for (final doc in docs)
                ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text("Cerveza ID: ${doc['beerId']}"),
                  subtitle: Text("Valoración: ${doc['rating']} ⭐"),
                ),
            ],
          );
        },
      ),
    );
  }
}
