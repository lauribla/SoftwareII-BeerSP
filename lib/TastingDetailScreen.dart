import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class TastingDetailScreen extends StatefulWidget {
  final String tastingId;

  const TastingDetailScreen({super.key, required this.tastingId});

  @override
  State<TastingDetailScreen> createState() => _TastingDetailScreenState();
}

class _TastingDetailScreenState extends State<TastingDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // -------------------------------
  // CARGA DATOS DEGUSTACIÓN
  // -------------------------------
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadTasting() {
    return FirebaseFirestore.instance
        .collection('tastings')
        .doc(widget.tastingId)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _loadComments() {
    return FirebaseFirestore.instance
        .collection('tastings')
        .doc(widget.tastingId)
        .collection('comentarios')
        .orderBy('fecha')
        .snapshots();
  }

  Future<Map<String, dynamic>?> _loadUser(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return snap.data();
  }

  Future<String> _loadVenueName(String? venueId) async {
    if (venueId == null) return "—";
    final snap = await FirebaseFirestore.instance
        .collection('venues')
        .doc(venueId)
        .get();
    if (!snap.exists) return "—";
    return snap.data()?["name"] ?? "—";
  }

  // -------------------------------
  // GUARDAR COMENTARIO
  // -------------------------------
  Future<void> _sendComment(
    String currentUserPhoto,
    String currentUserName,
  ) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('tastings')
        .doc(widget.tastingId)
        .collection('comentarios')
        .add({
          "texto": text,
          "nombreAutor": currentUserName,
          "fotoAutor": currentUserPhoto,
          "fecha": FieldValue.serverTimestamp(),
        });

    _commentCtrl.clear();
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final Color bg = Color.fromARGB(255, 230, 227, 210);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de degustación"),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadTasting(),
        builder: (context, snapTasting) {
          if (!snapTasting.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapTasting.data!.exists) {
            return const Center(child: Text("Degustación no encontrada"));
          }

          final tasting = snapTasting.data!.data()!;
          final beerId = tasting["beerId"];
          final authorUid = tasting["userUid"];
          final rating = tasting["rating"] ?? 0;
          final tastingNote = tasting["comment"] ?? "";
          final tastingPhoto = tasting["photoUrl"] ?? "";
          final venueId = tasting["venueId"];
          final createdAt = tasting["createdAt"] as Timestamp?;
          final currentUid = FirebaseAuth.instance.currentUser!.uid;

          return FutureBuilder(
            future: Future.wait([
              beerId != null
                  ? FirebaseFirestore.instance
                        .collection('beers')
                        .doc(beerId)
                        .get()
                  : Future.value(null),
              _loadUser(authorUid),
              _loadVenueName(venueId),
              _loadUser(currentUid),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // CERVEZA
              final beerSnap = snap.data![0];
              final beer = (beerSnap != null && beerSnap.exists)
                  ? beerSnap.data()
                  : null;

              // AUTOR DE LA DEGUSTACIÓN
              final tastingUser = snap.data![1] as Map<String, dynamic>? ?? {};
              final tastingUserName = tastingUser["username"] ?? "Usuario";
              final tastingUserPhoto =
                  tastingUser["fotoPerfil"] ??
                  tastingUser["photoUrl"] ??
                  tastingUser["avatar"] ??
                  tastingUser["profileImage"] ??
                  tastingUser["image"] ??
                  "";

              // LOCAL
              final venueName = snap.data![2] as String;

              // USUARIO ACTUAL
              final currentUser = snap.data![3] as Map<String, dynamic>? ?? {};
              final currentUserName = currentUser["username"] ?? "Usuario";
              final currentUserPhoto =
                  currentUser["fotoPerfil"] ??
                  currentUser["photoUrl"] ??
                  currentUser["avatar"] ??
                  currentUser["profileImage"] ??
                  currentUser["image"] ??
                  "";

              // DATOS CERVEZA
              final beerName = beer?["name"] ?? "Cerveza desconocida";
              final style = beer?["style"] ?? "—";
              final origin = beer?["originCountry"] ?? "—";
              final abv = beer?["abv"]?.toString() ?? "—";
              final ibu = beer?["ibu"]?.toString() ?? "—";
              final description = beer?["description"] ?? "Sin descripción";

              final formattedDate = createdAt != null
                  ? "${createdAt.toDate().day.toString().padLeft(2, '0')}/"
                        "${createdAt.toDate().month.toString().padLeft(2, '0')}/"
                        "${createdAt.toDate().year}"
                  : "—";

              // -------------------------------
              // UI FINAL
              // -------------------------------
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // FOTO
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 360,
                            maxHeight: 460,
                          ),
                          child: tastingPhoto.isEmpty
                              ? const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Icon(
                                      Icons.local_drink,
                                      size: 120,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  tastingPhoto,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DATOS CERVEZA
                    Text(
                      beerName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Estilo: $style"),
                    Text("Origen: $origin"),
                    Text("ABV: $abv%"),
                    Text("IBU: $ibu"),
                    const SizedBox(height: 20),

                    const Text(
                      "Descripción",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(description),
                    const SizedBox(height: 20),

                    // TARJETA DEGUSTACIÓN
                    Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.sports_bar, size: 22),
                              SizedBox(width: 6),
                              Text(
                                "Degustación",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: tastingUserPhoto.isNotEmpty
                                    ? NetworkImage(tastingUserPhoto)
                                    : const AssetImage(
                                            "assets/default_avatar.png",
                                          )
                                          as ImageProvider,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tastingUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      venueName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "$rating ★",
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          if (tastingNote.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(tastingNote),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // COMENTARIOS + INPUT
                    Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.chat_bubble_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Comentarios",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // INPUT SIN AVATAR
                          Container(
                            decoration: BoxDecoration(
                              color: bg.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Color.fromARGB(
                                  255,
                                  230,
                                  227,
                                  210,
                                ).withOpacity(0.2),
                                width: 1.2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentCtrl,
                                    decoration: const InputDecoration(
                                      hintText: "Añadir un comentario…",
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _sendComment(
                                    currentUserPhoto,
                                    currentUserName,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color.fromARGB(255, 230, 227, 210),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // LISTA DE COMENTARIOS
                          StreamBuilder(
                            stream: _loadComments(),
                            builder:
                                (
                                  context,
                                  AsyncSnapshot<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >
                                  snapComm,
                                ) {
                                  if (!snapComm.hasData) {
                                    return const LinearProgressIndicator();
                                  }

                                  final docs = snapComm.data!.docs;

                                  if (docs.isEmpty) {
                                    return const Text(
                                      "Todavía no hay comentarios sobre esta degustación 🥂",
                                      style: TextStyle(color: Colors.black54),
                                    );
                                  }

                                  return Column(
                                    children: docs.map((d) {
                                      final c = d.data();
                                      final author =
                                          c["nombreAutor"] ?? "Anónimo";
                                      final text = c["texto"] ?? "";
                                      final photo = c["fotoAutor"] ?? "";

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundImage: photo.isNotEmpty
                                                  ? NetworkImage(photo)
                                                  : const AssetImage(
                                                          "assets/default_avatar.png",
                                                        )
                                                        as ImageProvider,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    author,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(text),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
