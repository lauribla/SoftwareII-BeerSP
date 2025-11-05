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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Mis Amigos"),
            Tab(text: "Buscar Amigos"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Mis Amigos
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
                  child: _FriendsList(
                    myUid: myUid,
                    searchText: _searchFriendsCtrl.text,
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Buscar Amigos
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
                  child: _AllUsersList(
                    myUid: myUid,
                    searchText: _searchUsersCtrl.text,
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

// Widget para listar amigos
class _FriendsList extends StatelessWidget {
  final String myUid;
  final String searchText;

  const _FriendsList({required this.myUid, required this.searchText});

  Future<void> removeFriend(String myUid, String friendUid) async {
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final friendRef =
        FirebaseFirestore.instance.collection('users').doc(friendUid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.update(myRef, {'friends': FieldValue.arrayRemove([friendUid])});
        tx.update(friendRef, {'friends': FieldValue.arrayRemove([myUid])});
      });
    } catch (e) {
      debugPrint("Error al eliminar amigo: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data();
        if (userData == null || userData['friends'] == null) {
          return const Text("No tienes amigos todavía");
        }

        final friends = List<String>.from(userData['friends']);

        return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          future: Future.wait(
              friends.map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get())),
          builder: (context, userSnaps) {
            if (!userSnaps.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredUsers = userSnaps.data!
                .where((snap) =>
                    snap.exists &&
                    (snap.data()?['username'] ?? '')
                        .toLowerCase()
                        .contains(searchText.toLowerCase()))
                .toList();

            if (filteredUsers.isEmpty) {
              return const Text("No tienes amigos que coincidan con la búsqueda");
            }

            return ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, idx) {
                final user = filteredUsers[idx].data()!;
                final friendUid = filteredUsers[idx].id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photoUrl'] != null &&
                            user['photoUrl'].isNotEmpty
                        ? NetworkImage(user['photoUrl'])
                        : null,
                    child: (user['photoUrl'] == null || user['photoUrl'].isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['username'] ?? 'Usuario'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: "Eliminar amigo",
                    onPressed: () async {
                      try {
                        await removeFriend(myUid, friendUid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${user['username'] ?? 'Usuario'} eliminado de tus amigos'),
                          ),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("No se pudo eliminar el amigo, intenta de nuevo"),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Widget for listing all users
class _AllUsersList extends StatelessWidget {
  final String myUid;
  final String searchText;

  const _AllUsersList({required this.myUid, required this.searchText});

  Future<void> sendFriendRequest(String myUid, String otherUid) async {
    final otherUserRef =
        FirebaseFirestore.instance.collection('users').doc(otherUid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(otherUserRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final requests = List<String>.from(data['friendRequests'] ?? []);
      if (!requests.contains(myUid)) {
        tx.update(otherUserRef, {
          'friendRequests': FieldValue.arrayUnion([myUid])
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();

    final myUserDocStream =
        FirebaseFirestore.instance.collection('users').doc(myUid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myUserDocStream,
      builder: (context, meSnap) {
        if (!meSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final myData = meSnap.data!.data();
        final myFriends = List<String>.from(myData?['friends'] ?? []);
        final myRequests = List<String>.from(myData?['friendRequests'] ?? []);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: usersStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allUsers = snapshot.data!.docs
                .where((doc) =>
                    doc.id != myUid &&
                    (doc.data()['username'] ?? '')
                        .toLowerCase()
                        .contains(searchText.toLowerCase()))
                .toList();

            if (allUsers.isEmpty) {
              return const Center(
                  child: Text("No hay usuarios disponibles"));
            }

            return ListView.builder(
              itemCount: allUsers.length,
              itemBuilder: (context, idx) {
                final user = allUsers[idx].data();
                final userId = allUsers[idx].id;

                final isFriend = myFriends.contains(userId);
                final alreadyRequested = myRequests.contains(userId);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photoUrl'] != null &&
                            user['photoUrl'].isNotEmpty
                        ? NetworkImage(user['photoUrl'])
                        : null,
                    child: (user['photoUrl'] == null || user['photoUrl'].isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['username'] ?? 'Usuario'),
                  trailing: ElevatedButton(
                    child: const Icon(Icons.add),
                    onPressed: (isFriend || alreadyRequested)
                        ? null
                        : () async {
                            try {
                              await sendFriendRequest(myUid, userId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Solicitud enviada")),
                              );
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "No se pudo enviar la solicitud, intenta de nuevo")),
                              );
                            }
                          },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
