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

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  /// 🔎 Buscar usuarios por username
  Stream<QuerySnapshot<Map<String, dynamic>>> _searchUsers(String term) {
    if (term.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: term)
        .where('username', isLessThan: '${term}~')
        .limit(10)
        .snapshots();
  }

  /// 📤 Enviar solicitud de amistad
  Future<void> _sendFriendRequest(String otherUid) async {
    final ref = FirebaseFirestore.instance.collection('friendships');
    await ref.add({
      'senderUid': myUid,
      'receiverUid': otherUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Solicitud enviada")),
    );
  }

  /// 📥 Aceptar solicitud
  Future<void> _acceptRequest(String requestId, String senderUid) async {
    final ref =
        FirebaseFirestore.instance.collection('friendships').doc(requestId);

    await ref.update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 📰 Añadir actividad
    await FirebaseFirestore.instance.collection('activities').add({
      'type': 'friendAccepted',
      'actorUid': myUid,
      'targetIds': {'friendUid': senderUid},
      'createdAt': FieldValue.serverTimestamp(),
      'public': false,
    });
  }

  /// ❌ Rechazar solicitud
  Future<void> _rejectRequest(String requestId) async {
    final ref =
        FirebaseFirestore.instance.collection('friendships').doc(requestId);

    await ref.update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 👥 Stream de solicitudes recibidas
  Stream<QuerySnapshot<Map<String, dynamic>>> _incomingRequests() {
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('receiverUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// 👥 Stream de solicitudes enviadas (pendientes)
  Stream<QuerySnapshot<Map<String, dynamic>>> _outgoingRequests() {
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('senderUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// 👥 Stream de amigos confirmados
  Stream<QuerySnapshot<Map<String, dynamic>>> _friends() {
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('senderUid', isEqualTo: myUid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Amigos"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔎 Buscador
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: "Buscar usuarios",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Resultados de búsqueda
          if (_searchCtrl.text.isNotEmpty)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _searchUsers(_searchCtrl.text.trim()),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("No se encontraron usuarios");
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Resultados:"),
                    for (final doc in snapshot.data!.docs)
                      if (doc.id != myUid)
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(doc['username'] ?? "Usuario"),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add),
                            onPressed: () => _sendFriendRequest(doc.id),
                          ),
                        ),
                  ],
                );
              },
            ),

          const Divider(),

          // 📥 Solicitudes recibidas
          const Text("Solicitudes recibidas:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _incomingRequests(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("No tienes solicitudes nuevas");
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  return ListTile(
                    leading: const Icon(Icons.mail),
                    title: Text("Solicitud de ${doc['senderUid']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () =>
                              _acceptRequest(doc.id, doc['senderUid']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectRequest(doc.id),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const Divider(),

          // 📤 Solicitudes enviadas
          const Text("Solicitudes enviadas:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _outgoingRequests(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("No tienes solicitudes enviadas");
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  return ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text("Enviada a ${doc['receiverUid']}"),
                    subtitle: const Text("Pendiente"),
                  );
                }).toList(),
              );
            },
          ),

          const Divider(),

          // 👥 Amigos confirmados
          const Text("Tus amigos:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _friends(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("Todavía no tienes amigos confirmados");
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final friendUid = doc['receiverUid'];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text("Amigo: $friendUid"),
                    subtitle: const Text("Confirmado"),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
