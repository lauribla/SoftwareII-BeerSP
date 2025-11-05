import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Introduce tu nombre' : null,
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

              // 🔒 Botón de Cerrar sesión
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
