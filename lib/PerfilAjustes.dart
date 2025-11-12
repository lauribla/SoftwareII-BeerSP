import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

class PerfilAjustesScreen extends StatefulWidget {
  const PerfilAjustesScreen({Key? key}) : super(key: key);

  @override
  State<PerfilAjustesScreen> createState() => _PerfilAjustesScreenState();
}

class _PerfilAjustesScreenState extends State<PerfilAjustesScreen> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  // Controladores
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _paisController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  DateTime? _fechaNacimiento;
  File? _nuevaFoto;
  String? _fotoUrl;

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();

    if (snapshot.exists) {
      final data = snapshot.data()!;
      _nombreController.text = data['nombre'] ?? '';
      _apellidoController.text = data['apellido'] ?? '';
      _emailController.text = data['email'] ?? user?.email ?? '';
      _ubicacionController.text = data['ubicacion'] ?? '';
      _generoController.text = data['genero'] ?? '';
      _paisController.text = data['pais'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _fotoUrl = data['photoUrl'];
      if (data['fechaNacimiento'] != null) {
        _fechaNacimiento = (data['fechaNacimiento'] as Timestamp).toDate();
      }
    }

    setState(() => _cargando = false);
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _nuevaFoto = File(picked.path));
    }
  }

  Future<String?> _subirFotoPerfil(String uid) async {
    if (_nuevaFoto == null) return _fotoUrl;

    final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
    await ref.putFile(_nuevaFoto!);
    return await ref.getDownloadURL();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    String? nuevaFotoUrl = await _subirFotoPerfil(currentUser!.uid);

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'nombre': _nombreController.text.trim(),
      'apellido': _apellidoController.text.trim(),
      'email': _emailController.text.trim(),
      'ubicacion': _ubicacionController.text.trim(),
      'genero': _generoController.text.trim(),
      'pais': _paisController.text.trim(),
      'bio': _bioController.text.trim(),
      'fechaNacimiento': _fechaNacimiento != null
          ? Timestamp.fromDate(_fechaNacimiento!)
          : null,
      'photoUrl': nuevaFotoUrl,
    });

    // ✅ Actualizar email de usuario en Firebase Auth (FirebaseAuth 6.1.2)
    if (_emailController.text.trim() != currentUser.email) {
      try {
        await currentUser.verifyBeforeUpdateEmail(_emailController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo actualizado, verifica tu nuevo email.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el correo: $e')),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        context.pop();
      });
    }
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
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📸 Foto de perfil
              Center(
                child: GestureDetector(
                  onTap: _seleccionarFoto,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _nuevaFoto != null
                        ? FileImage(_nuevaFoto!)
                        : (_fotoUrl != null
                            ? NetworkImage(_fotoUrl!) as ImageProvider
                            : const AssetImage('assets/default_avatar.png')),
                    child: const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Introduce tu nombre' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(
                  labelText: "Apellidos",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Introduce tu correo' : null,
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
                controller: _generoController,
                decoration: const InputDecoration(
                  labelText: "Género",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _paisController,
                decoration: const InputDecoration(
                  labelText: "País",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: "Presentación / Bio",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // 📅 Fecha de cumpleaños
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fechaNacimiento != null
                          ? 'Cumpleaños: ${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
                          : 'Selecciona tu fecha de cumpleaños',
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Elegir fecha'),
                    onPressed: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate:
                            _fechaNacimiento ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (fecha != null) {
                        setState(() => _fechaNacimiento = fecha);
                      }
                    },
                  ),
                ],
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

              // 🔒 Cerrar sesión
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}
