import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PerfilAjustesScreen extends StatefulWidget {
  const PerfilAjustesScreen({Key? key}) : super(key: key);

  @override
  State<PerfilAjustesScreen> createState() => _PerfilAjustesScreenState();
}

class _PerfilAjustesScreenState extends State<PerfilAjustesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data()!;
      _nombreController.text = data['nombre'] ?? '';
      _ubicacionController.text = data['ubicacion'] ?? '';
      _bioController.text = data['bio'] ?? '';
    }

    setState(() => _cargando = false);
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
      'nombre': _nombreController.text.trim(),
      'ubicacion': _ubicacionController.text.trim(),
      'bio': _bioController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado correctamente')),
    );
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/auth');
  }

  Future<void> _actualizarFotoPerfil() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // 1️⃣ Leer la imagen seleccionada
    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 2️⃣ Subir a ImgBB
    const apiKey =
        'c25c03fcf2ff1d284b05c5e2478dc842'; // ⚠️ Usa la misma que en CrearCerveza.dart
    final response = await http.post(
      Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
      body: {'image': base64Image},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final imageUrl = data['data']['url'];

      // 3️⃣ Guardar en Firestore
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fotoPerfil': imageUrl},
      );

      // 4️⃣ Refrescar la interfaz
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada correctamente')),
        );
        setState(() {}); // Recarga la vista con la nueva imagen
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al subir la imagen')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes del perfil'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'), // 🔙 volver atrás
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 FOTO DE PERFIL
              Center(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 50),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final fotoPerfil = data?['fotoPerfil'] as String?;

                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              (fotoPerfil != null && fotoPerfil.isNotEmpty)
                              ? NetworkImage(fotoPerfil)
                              : const AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _actualizarFotoPerfil,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cambiar foto de perfil'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 🧾 CAMPOS DE TEXTO
              const Text(
                "Editar perfil",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre de usuario",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Introduce tu nombre'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ubicacionController,
                decoration: const InputDecoration(
                  labelText: "Ubicación",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: "Biografía / Descripción",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              Center(
                child: ElevatedButton.icon(
                  onPressed: _guardarCambios,
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar cambios"),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 10),

              // 🔒 CERRAR SESIÓN
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "Cerrar sesión",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
