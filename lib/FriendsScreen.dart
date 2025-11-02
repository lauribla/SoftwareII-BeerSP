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
    with SingleTickerProviderStateMixin {
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
          // Tab 1: My Friends
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
          // Tab 2: Find Friends
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

// Widget for listing friends
class _FriendsList extends StatelessWidget {
  final String myUid;
  final String searchText;

  const _FriendsList({required this.myUid, required this.searchText});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              return const Center(child: CircularProgressIndicator());
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

            return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              future: Future.wait(friends.map((uid) =>
                  FirebaseFirestore.instance.collection('users').doc(uid).get())),
              builder: (context, userSnaps) {
                if (!userSnaps.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = userSnaps.data!
                    .where((snap) =>
                        snap.exists &&
                        (snap.data()?['username'] ?? '')
                            .toLowerCase()
                            .contains(searchText.toLowerCase()))
                    .toList();
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final user = filtered[idx].data()!;
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
                    );
                  },
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final filtered = snapshot.data!.docs
            .where((doc) =>
                doc.id != myUid &&
                (doc.data()['username'] ?? '')
                    .toLowerCase()
                    .contains(searchText.toLowerCase()))
            .toList();
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, idx) {
            final user = filtered[idx].data();
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
                child: const Icon(Icons.add),
                onPressed: () {
                  // Lógica para enviar solicitud de amistad
                  // Puedes llamar a tu función _sendFriendRequest aquí si la pasas como callback
                },
              ),
            );
          },
        );
      },
    );
  }
}
