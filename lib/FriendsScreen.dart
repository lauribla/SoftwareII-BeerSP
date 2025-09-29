import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();

  Future<void> _sendFriendRequest(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('friendships').add({
      'senderUid': myUid,
      'receiverUid': otherUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Solicitud enviada")),
    );
  }

  Future<void> _acceptRequest(String friendshipId) async {
    await FirebaseFirestore.instance
        .collection('friendships')
        .doc(friendshipId)
        .update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Amigos"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔎 Buscar usuarios
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: "Buscar por username",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: [
                  // 📨 Solicitudes recibidas
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('friendships')
                        .where('receiverUid', isEqualTo: myUid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Solicitudes recibidas",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          for (final doc in snapshot.data!.docs)
                            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(doc['senderUid'])
                                  .get(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData || !userSnap.data!.exists) {
                                  return const ListTile(
                                    title: Text("Usuario desconocido"),
                                  );
                                }
                                final user = userSnap.data!.data()!;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: user['photoUrl'] != null &&
                                            user['photoUrl'].isNotEmpty
                                        ? NetworkImage(user['photoUrl'])
                                        : null,
                                    child: (user['photoUrl'] == null ||
                                            user['photoUrl'].isEmpty)
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(user['username'] ?? 'Usuario'),
                                  trailing: ElevatedButton(
                                    onPressed: () =>
                                        _acceptRequest(doc.id),
                                    child: const Text("Aceptar"),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ✅ Tus amigos
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('friendships')
                        .where('status', isEqualTo: 'accepted')
                        .where('senderUid', isEqualTo: myUid)
                        .snapshots(),
                    builder: (context, snapshot1) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('friendships')
                            .where('status', isEqualTo: 'accepted')
                            .where('receiverUid', isEqualTo: myUid)
                            .snapshots(),
                        builder: (context, snapshot2) {
                          if (!snapshot1.hasData && !snapshot2.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final friends = <String>{};
                          if (snapshot1.hasData) {
                            for (var doc in snapshot1.data!.docs) {
                              friends.add(doc['receiverUid']);
                            }
                          }
                          if (snapshot2.hasData) {
                            for (var doc in snapshot2.data!.docs) {
                              friends.add(doc['senderUid']);
                            }
                          }

                          if (friends.isEmpty) {
                            return const Text("No tienes amigos todavía");
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Tus amigos",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              for (final friendUid in friends)
                                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(friendUid)
                                      .get(),
                                  builder: (context, userSnap) {
                                    if (!userSnap.hasData ||
                                        !userSnap.data!.exists) {
                                      return const ListTile(
                                        title: Text("Usuario desconocido"),
                                      );
                                    }
                                    final user = userSnap.data!.data()!;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: user['photoUrl'] !=
                                                    null &&
                                                user['photoUrl'].isNotEmpty
                                            ? NetworkImage(user['photoUrl'])
                                            : null,
                                        child: (user['photoUrl'] == null ||
                                                user['photoUrl'].isEmpty)
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      title:
                                          Text(user['username'] ?? 'Usuario'),
                                    );
                                  },
                                ),
                            ],
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
      ),
    );
  }
}
