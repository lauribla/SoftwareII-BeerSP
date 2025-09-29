import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class CrearCervezaScreen extends StatefulWidget {
  const CrearCervezaScreen({super.key});

  @override
  State<CrearCervezaScreen> createState() => _CrearCervezaScreenState();
}

class _CrearCervezaScreenState extends State<CrearCervezaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _styleCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  File? _imageFile;
  bool _loading = false;
  bool _isFavorite = false; // ⭐ Nuevo campo para favoritas

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String beerId) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child("beers/$beerId.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveTasting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;

      // === 1. Guardar/obtener cerveza en "beers" ===
      final beersRef = FirebaseFirestore.instance.collection('beers');
      final query = await beersRef
          .where('name', isEqualTo: _nameCtrl.text.trim())
          .limit(1)
          .get();

      String beerId;
      if (query.docs.isEmpty) {
        final newBeer = await beersRef.add({
          'name': _nameCtrl.text.trim(),
          'style': _styleCtrl.text.trim(),
          'originCountry': _countryCtrl.text.trim(),
          'createdBy': myUid,
          'createdAt': FieldValue.serverTimestamp(),
          'ratingAvg': 0,
          'ratingCount': 0,
        });
        beerId = newBeer.id;
      } else {
        beerId = query.docs.first.id;
      }

      // Subir foto (opcional)
      final photoUrl = await _uploadImage(beerId);

      // === 2. Guardar degustación en "tastings" ===
      final tastingRef =
          await FirebaseFirestore.instance.collection('tastings').add({
        'userUid': myUid,
        'beerId': beerId,
        'rating': double.tryParse(_ratingCtrl.text.trim()) ?? 0,
        'comment': _commentCtrl.text.trim(),
        'photoUrl': photoUrl,
        'isFavorite': _isFavorite, // ⭐ Aquí se guarda favorita o no
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': DateTime.now().toIso8601String(), // ⭐ nuevo
      });

      // === 3. Añadir actividad en "activities" ===
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'tasting',
        'actorUid': myUid,
        'targetIds': {
          'beerId': beerId,
          'tastingId': tastingRef.id,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'public': true,
      });

      // === 4. Actualizar estadísticas del usuario ===
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(myUid);
      await userRef.set({
        'stats': {
          'tastingsTotal': FieldValue.increment(1),
          'tastings7d': FieldValue.increment(1),
        }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Degustación registrada')),
        );
        context.go('/'); // volver al Home
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar degustación"),
        leading: BackButton(onPressed: () => context.pop()), // 🔙 botón volver
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nombre cerveza"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Introduce un nombre" : null,
              ),
              TextFormField(
                controller: _styleCtrl,
                decoration: const InputDecoration(labelText: "Estilo"),
              ),
              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: "País de origen"),
              ),
              TextFormField(
                controller: _ratingCtrl,
                decoration:
                    const InputDecoration(labelText: "Valoración (0-5)"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _commentCtrl,
                decoration: const InputDecoration(labelText: "Comentario"),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text("Marcar como favorita ⭐"),
                value: _isFavorite,
                onChanged: (val) =>
                    setState(() => _isFavorite = val ?? false),
              ),
              const SizedBox(height: 12),
              if (_imageFile != null)
                Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Subir foto"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _saveTasting,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar degustación"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
