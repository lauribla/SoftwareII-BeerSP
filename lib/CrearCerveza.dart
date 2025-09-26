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

  final _venueNameCtrl = TextEditingController();
  final _venueAddressCtrl = TextEditingController();

  File? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String tastingId) async {
    if (_imageFile == null) return null;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ref = FirebaseStorage.instance
        .ref()
        .child("tastings")
        .child(uid)
        .child("$tastingId.jpg");

    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveTasting() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("Usuario no logueado");

      // 1. Buscar si existe cerveza con ese nombre
      final beerQuery = await FirebaseFirestore.instance
          .collection('beers')
          .where('name', isEqualTo: _nameCtrl.text.trim())
          .limit(1)
          .get();

      String beerId;
      if (beerQuery.docs.isEmpty) {
        final beerRef =
            await FirebaseFirestore.instance.collection('beers').add({
          'name': _nameCtrl.text.trim(),
          'style': _styleCtrl.text.trim(),
          'originCountry': _countryCtrl.text.trim(),
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'ratingAvg': 0,
          'ratingCount': 0,
        });
        beerId = beerRef.id;
      } else {
        beerId = beerQuery.docs.first.id;
      }

      // 2. Crear o buscar venue
      String? venueId;
      if (_venueNameCtrl.text.trim().isNotEmpty) {
        final venueQuery = await FirebaseFirestore.instance
            .collection('venues')
            .where('name', isEqualTo: _venueNameCtrl.text.trim())
            .limit(1)
            .get();

        if (venueQuery.docs.isEmpty) {
          final venueRef =
              await FirebaseFirestore.instance.collection('venues').add({
            'name': _venueNameCtrl.text.trim(),
            'address': _venueAddressCtrl.text.trim(),
            'country': _countryCtrl.text.trim(),
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          venueId = venueRef.id;
        } else {
          venueId = venueQuery.docs.first.id;
        }
      }

      // 3. Crear tasting
      final rating =
          double.tryParse(_ratingCtrl.text.trim().replaceAll(',', '.')) ?? 0;

      final tastingRef =
          await FirebaseFirestore.instance.collection('tastings').add({
        'userUid': uid,
        'beerId': beerId,
        'venueId': venueId,
        'rating': rating,
        'comment': _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'photoUrl': null,
      });

      // 4. Subir foto si hay
      final photoUrl = await _uploadImage(tastingRef.id);
      if (photoUrl != null) {
        await tastingRef.update({'photoUrl': photoUrl});
      }

      // 5. Registrar actividad
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'tasting',
        'actorUid': uid,
        'targetIds': {
          'beerId': beerId,
          'tastingId': tastingRef.id,
          'venueId': venueId
        },
        'createdAt': FieldValue.serverTimestamp(),
        'public': true,
      });

      if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Degustación registrada')),
  );
  // Vuelve al Home en lugar de quedarse en blanco
  context.go('/');
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
      appBar: AppBar(title: const Text("Registrar degustación")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nombre de la cerveza"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Introduce un nombre" : null,
              ),
              TextFormField(
                controller: _styleCtrl,
                decoration: const InputDecoration(labelText: "Estilo (ej: IPA, Lager...)"),
              ),
              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: "País de origen"),
              ),
              TextFormField(
                controller: _ratingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Valoración (0–5)"),
              ),
              TextFormField(
                controller: _commentCtrl,
                decoration: const InputDecoration(labelText: "Comentario"),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text("Asociar a un local (opcional)",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _venueNameCtrl,
                decoration: const InputDecoration(labelText: "Nombre del local"),
              ),
              TextFormField(
                controller: _venueAddressCtrl,
                decoration: const InputDecoration(labelText: "Dirección del local"),
              ),
              const SizedBox(height: 20),
              if (_imageFile != null)
                Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Añadir foto"),
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
