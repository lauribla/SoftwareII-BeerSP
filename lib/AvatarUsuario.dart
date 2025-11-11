import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvatarUsuario extends StatelessWidget {
  final String? userId;
  final double radius;

  const AvatarUsuario({Key? key, this.userId, this.radius = 20})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, size: 18),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final fotoPerfil = data?['fotoPerfil'] as String?;

        return CircleAvatar(
          radius: radius,
          backgroundImage: (fotoPerfil != null && fotoPerfil.isNotEmpty)
              ? NetworkImage(fotoPerfil)
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        );
      },
    );
  }
}
