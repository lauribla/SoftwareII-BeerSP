import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data'; // Flutter Web
import 'package:flutter/foundation.dart' show kIsWeb; // Flutter Web
import 'dart:convert';  // Flutter Web - ImgBB
import 'package:http/http.dart' as http; // Flutter Web - ImgBB

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
  Uint8List? _webImage; // 🌐 Imagen para Flutter Web
  bool _loading = false;
  bool _isFavorite = false; // ⭐ Nuevo campo para favoritas

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
      // 🌐 Web - se leen los bytes de la imagen
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImage = bytes; // Nuevo campo (tipo Uint8List)
          _imageFile = null; // Para que no se use File en la web
        });
      } else {
        // 📱 Móvil o escritorio
        setState(() {
          _imageFile = File(picked.path);
          _webImage = null;
        });
      }
    }
  }

  Future<String?> _uploadImage(String beerId) async {
    if (_imageFile == null && _webImage == null) return null;
    // 🌐 Web - subida a ImgBB
    if (kIsWeb && _webImage != null) {
      try {
        const apiKey = "c25c03fcf2ff1d284b05c5e2478dc842"; // Clave de API - ImgBB
        final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
        // Convierte la imagen a base64
        final base64Image = base64Encode(_webImage!);
        // Petición POST a ImgBB
        final response = await http.post(url, body: {
          'image': base64Image,
          'name': 'beer_$beerId',
        });
        if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data']['url'];
        return imageUrl; // URL pública
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }
    // 📱 Android / iOS - Firebase Storage
    if (_imageFile != null) {
      try {
      final ref = FirebaseStorage.instance.ref().child("beers/$beerId.jpg");
      await ref.putFile(_imageFile!);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
      } catch (e) {
        return null;
      }
    }
    return null;
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
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await beersRef.doc(beerId).update({
          'photoUrl': photoUrl,
        });
      }

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
        leading: BackButton(onPressed: () => context.go('/')), // 🔙 volver atrás
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
              if (kIsWeb && _webImage != null)
                Image.memory(_webImage!, height: 150, fit: BoxFit.cover)
              else if (!kIsWeb && _imageFile != null)
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
