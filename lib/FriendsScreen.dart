import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchFriendsCtrl = TextEditingController();
  final _searchUsersCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFriendsCtrl.dispose();
    _searchUsersCtrl.dispose();
    super.dispose();
  }

  // 🔹 Obtiene la foto de perfil del usuario (independientemente del campo usado)
  ImageProvider getUserAvatar(Map<String, dynamic> user) {
    final foto = (user['fotoPerfil'] ?? user['photoUrl'] ?? '')
        .toString()
        .trim();

    if (foto.isNotEmpty) {
      return NetworkImage(foto);
    } else {
      return const AssetImage('assets/default_avatar.png');
    }
  }

  Future<void> _sendFriendRequest(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(otherUid).update({
      'friendRequests': FieldValue.arrayUnion([myUid]),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Solicitud enviada")));
  }

  Future<void> _removeFriend(String friendUid) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final friendRef = FirebaseFirestore.instance
        .collection('users')
        .doc(friendUid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(myRef, {
        'friends': FieldValue.arrayRemove([friendUid]),
      });
      tx.update(friendRef, {
        'friends': FieldValue.arrayRemove([myUid]),
      });
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Amigo eliminado")));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Amigos"),
        leading: BackButton(onPressed: () => context.go('/')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Mis amigos"),
            Tab(text: "Buscar amigos"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 🧩 TAB 1: MIS AMIGOS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchFriendsCtrl,
                  decoration: const InputDecoration(
                    labelText: "Buscar en tus amigos",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(myUid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final myData = snapshot.data!.data();
                      final friends = List<String>.from(
                        myData?['friends'] ?? [],
                      );

                      if (friends.isEmpty) {
                        return const Text("No tienes amigos todavía");
                      }

                      return FutureBuilder<
                        List<DocumentSnapshot<Map<String, dynamic>>>
                      >(
                        future: Future.wait(
                          friends.map(
                            (uid) => FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get(),
                          ),
                        ),
                        builder: (context, friendSnaps) {
                          if (!friendSnaps.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final filtered = friendSnaps.data!
                              .where(
                                (snap) =>
                                    snap.exists &&
                                    (snap.data()?['username'] ?? '')
                                        .toLowerCase()
                                        .contains(
                                          _searchFriendsCtrl.text.toLowerCase(),
                                        ),
                              )
                              .toList();

                          if (filtered.isEmpty) {
                            return const Text(
                              "No hay amigos que coincidan con la búsqueda",
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final user = filtered[idx].data()!;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundImage: getUserAvatar(user),
                                ),
                                title: Text(user['username'] ?? 'Usuario'),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _removeFriend(filtered[idx].id),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 🧩 TAB 2: BUSCAR AMIGOS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchUsersCtrl,
                  decoration: const InputDecoration(
                    labelText: "Buscar gente en BeerSP",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!.docs
                          .where(
                            (doc) =>
                                doc.id != myUid &&
                                (doc.data()['username'] ?? '')
                                    .toLowerCase()
                                    .contains(
                                      _searchUsersCtrl.text.toLowerCase(),
                                    ),
                          )
                          .toList();
                      if (users.isEmpty) {
                        return const Text("No hay usuarios disponibles");
                      }

                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(myUid)
                            .snapshots(),
                        builder: (context, meSnap) {
                          if (!meSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final myData = meSnap.data!.data();
                          final myFriends = List<String>.from(
                            myData?['friends'] ?? [],
                          );
                          final myRequests = List<String>.from(
                            myData?['friendRequests'] ?? [],
                          );

                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, idx) {
                              final user = users[idx].data();
                              final userId = users[idx].id;
                              final isFriend = myFriends.contains(userId);
                              final alreadyRequested = myRequests.contains(
                                userId,
                              );

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundImage: getUserAvatar(user),
                                ),
                                title: Text(user['username'] ?? 'Usuario'),
                                trailing: ElevatedButton(
                                  onPressed: (isFriend || alreadyRequested)
                                      ? null
                                      : () => _sendFriendRequest(userId),
                                  child: const Icon(Icons.add),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
