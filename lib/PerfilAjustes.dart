import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class PerfilAjustesScreen extends StatefulWidget {
  const PerfilAjustesScreen({super.key});

  @override
  State<PerfilAjustesScreen> createState() => _PerfilAjustesScreenState();
}

class _PerfilAjustesScreenState extends State<PerfilAjustesScreen> {
  final _formKey = GlobalKey<FormState>();

  // controladores
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _selectedGender;

  File? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child("users/$uid/profile.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _usernameCtrl.text = data['username'] ?? '';
    _displayNameCtrl.text = data['displayName'] ?? '';
    _surnameCtrl.text = data['surname'] ?? '';
    _countryCtrl.text = data['country'] ?? '';
    _locationCtrl.text = data['location'] ?? '';
    _bioCtrl.text = data['bio'] ?? '';
    _selectedGender = data['gender'];
    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no logueado");
      final uid = user.uid;

      String? photoUrl = await _uploadImage(uid);

      // 🔄 Actualizar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': _usernameCtrl.text.trim(),
        'displayName': _displayNameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'gender': _selectedGender ?? '',
        'country': _countryCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 🔄 También en FirebaseAuth
      await user.updateDisplayName(_usernameCtrl.text.trim());
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado")),
        );
        context.pop(); // volver al Home
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil / Ajustes"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 🖼 Imagen de perfil
              if (_imageFile != null)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: FileImage(_imageFile!),
                )
              else
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get(),
                  builder: (context, snapshot) {
                    final photoUrl = snapshot.data?.data()?['photoUrl'];
                    return CircleAvatar(
                      radius: 50,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    );
                  },
                ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Cambiar foto"),
              ),

              // Campos de edición
              TextFormField(
                controller: _usernameCtrl,
                decoration:
                    const InputDecoration(labelText: "Nombre de usuario"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Introduce un nombre" : null,
              ),
              TextFormField(
                controller: _displayNameCtrl,
                decoration:
                    const InputDecoration(labelText: "Nombre a mostrar"),
              ),
              TextFormField(
                controller: _surnameCtrl,
                decoration: const InputDecoration(labelText: "Apellidos"),
              ),

              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: 'Género'),
                items: const [
                  DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  DropdownMenuItem(
                      value: 'Prefiero no decirlo',
                      child: Text('Prefiero no decirlo')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: "País"),
              ),
              TextFormField(
                controller: _locationCtrl,
                decoration:
                    const InputDecoration(labelText: "Ubicación (ciudad)"),
              ),
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(labelText: "Biografía"),
                maxLines: 3,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar cambios"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
