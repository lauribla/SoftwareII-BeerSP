import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopDegustacionesScreen extends StatelessWidget {
  const TopDegustacionesScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadTopBeers() {
    return FirebaseFirestore.instance
        .collection('beers')
        .orderBy('ratingAvg', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Top Degustaciones")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadTopBeers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay cervezas registradas aún"));
          }

          final beers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: beers.length,
            itemBuilder: (context, index) {
              final data = beers[index].data();
              final name = data['name'] ?? 'Desconocida';
              final style = data['style'] ?? '—';
              final country = data['originCountry'] ?? '—';
              final rating = data['ratingAvg']?.toStringAsFixed(1) ?? '0.0';
              final count = data['ratingCount'] ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  child: Text("${index + 1}"),
                ),
                title: Text(name),
                subtitle: Text("$style • $country"),
                trailing: Text("$rating ⭐ ($count)"),
              );
            },
          );
        },
      ),
    );
  }
}
