import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GalardonesScreen extends StatelessWidget {
  const GalardonesScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadAllBadges(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Debes iniciar sesión")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mis galardones")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadAllBadges(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Todavía no tienes galardones"),
            );
          }

          final badges = snapshot.data!.docs;

          return ListView.builder(
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final data = badges[index].data();
              final level = data['level'] ?? 0;
              final earnedAt = (data['earnedAt'] as Timestamp?)?.toDate();

              return ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.orange),
                title: Text("Galardón: ${badges[index].id}"),
                subtitle: Text(
                  "Nivel: $level\nObtenido: ${earnedAt != null ? earnedAt.toLocal().toString().split(' ')[0] : '—'}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}
