import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'award_manager.dart';


class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Solicitudes de amistad",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildFriendRequestsSection(),
            const Divider(height: 32, thickness: 1),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Nuevos galardones",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildBadgesNotificationsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// --- Solicitudes de amistad pendientes ---
  Widget _buildFriendRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No tienes solicitudes de amistad pendientes."),
          );
        }

        return Column(
          children: requests.map((req) {
            final data = req.data() as Map<String, dynamic>;
            final fromName = data['fromName'] ?? 'Usuario desconocido';
            final fromId = data['from'] ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text("$fromName te ha enviado una solicitud"),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _acceptFriendRequest(req.id, fromId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectFriendRequest(req.id),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _acceptFriendRequest(String requestId, String fromId) async {
    final uid = user?.uid;
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final requestRef =
        FirebaseFirestore.instance.collection('friend_requests').doc(requestId);

    // Actualizar estado de la solicitud
    batch.update(requestRef, {'status': 'accepted'});

    // Añadir a la lista de amigos en ambas direcciones
    final friendsRef = FirebaseFirestore.instance.collection('friends');
    batch.set(friendsRef.doc('${uid}_$fromId'), {'user1': uid, 'user2': fromId});
    batch.set(friendsRef.doc('${fromId}_$uid'), {'user1': fromId, 'user2': uid});

    await batch.commit();

        // --- Actualizar contador de amigos y comprobar galardones ---
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final stats = (userSnap.data()?['stats'] as Map<String, dynamic>?) ?? {};

    final int currentFriends =
        stats['friendsCount'] is num ? (stats['friendsCount'] as num).toInt() : 0;
    final int newFriendsCount = currentFriends + 1;

    await userRef.set({
      'stats': {
        'friendsCount': FieldValue.increment(1),
      }
    }, SetOptions(merge: true));

    final newAwards = await AwardManager.checkAndGrantTastingAwards(
      uid: uid,
      tastingsTotal: newFriendsCount, // reutilizamos el motor
    );

    if (mounted && newAwards.isNotEmpty) {
      for (final award in newAwards) {
        await _showAwardDialog(award);
      }
    }

  }

  Future<void> _rejectFriendRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  /// --- Notificaciones de galardones ---
  Widget _buildBadgesNotificationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notificaciones')
          .where('uid', isEqualTo: user?.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final badges = snapshot.data!.docs;

        if (badges.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No hay nuevos galardones."),
          );
        }

        return Column(
          children: badges.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Galardón';
            final nivel = data['nivel'] ?? '';
            final fecha = data['fecha'] != null
                ? (data['fecha'] as Timestamp).toDate()
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: Text("$nombre (Nivel $nivel)"),
                subtitle: Text(
                  fecha != null
                      ? "Obtenido el ${fecha.day}/${fecha.month}/${fecha.year}"
                      : "Nuevo galardón desbloqueado",
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
