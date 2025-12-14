import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class GalardonesScreen extends StatelessWidget {
  const GalardonesScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadBadges(String uid) {
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
      appBar: AppBar(
        title: const Text("Galardones"),
        leading: BackButton(onPressed: () => context.pop()), // volver atrás
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _loadBadges(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Todavía no tienes galardones"));
          }

          final docs = snapshot.data!.docs;

          return ListView(
            children: [
              for (final doc in docs)
                ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.orange),
                  title: Text("Galardón: ${doc.id}"),
                  subtitle: Text("Nivel: ${doc['level']}"),
                ),
            ],
          );
        },
      ),
    );
  }
}
