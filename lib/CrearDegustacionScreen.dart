import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'award_manager.dart';


import 'CrearCervezaScreen.dart';
import 'CrearLocalScreen.dart';

class CrearDegustacionScreen extends StatefulWidget {
  const CrearDegustacionScreen({super.key});

  @override
  State<CrearDegustacionScreen> createState() => _CrearDegustacionScreenState();
}

class _CrearDegustacionScreenState extends State<CrearDegustacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentCtrl = TextEditingController();

  File? _imageFile;
  Uint8List? _webImage;
  bool _loading = false;

  Map<String, dynamic>? selectedBeer;
  Map<String, dynamic>? selectedVenue;

  double rating = 0.0;
  bool _isFavorite = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImage = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
          _webImage = null;
        });
      }
    }
  }

  Future<String?> _uploadImage(String tastingId) async {
    if (_imageFile == null && _webImage == null) return null;
    // Subida - web
    if (kIsWeb && _webImage != null) {
      try {
        const apiKey = "c25c03fcf2ff1d284b05c5e2478dc842";
        final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
        final base64Image = base64Encode(_webImage!);
        final response = await http.post(
          url,
          body: {'image': base64Image, 'name': 'tasting_$tastingId'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['data']['url'];
        }
      } catch (e) {
        return null;
      }
    }
    // Subida - móvil
    if (_imageFile != null) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          "tastings/$tastingId.jpg",
        );
        await ref.putFile(_imageFile!);
        return await ref.getDownloadURL();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> _saveDegustacion() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBeer == null || selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar cerveza y local')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;

      // Crear o tomar cerveza existente
      final beersRef = FirebaseFirestore.instance.collection('beers');
      String beerId;

      if (!selectedBeer!.containsKey('id')) {
        final newBeer = await beersRef.add(selectedBeer!);
        beerId = newBeer.id;
      } else {
        beerId = selectedBeer!['id'];
      }

      // Crear o tomar local existente
      final venuesRef = FirebaseFirestore.instance.collection('venues');
      String venueId;

      if (!selectedVenue!.containsKey('id')) {
        final newVenue = await venuesRef.add(selectedVenue!);
        venueId = newVenue.id;
      } else {
        venueId = selectedVenue!['id'];
      }

      // Crear degustación SIN foto todavía
      final tastingRef = await FirebaseFirestore.instance
          .collection('tastings')
          .add({
            'userUid': myUid,
            'beerId': beerId,
            'venueId': venueId,
            'rating': rating,
            'comment': _commentCtrl.text.trim(),
            'photoUrl': null, // se actualiza luego
            'isFavorite': _isFavorite,
            'createdAt': FieldValue.serverTimestamp(),
            'createdAtLocal': DateTime.now().toIso8601String(),
          });

      // SUBIR FOTO (si existe), asociada a tastingId
      final photoUrl = await _uploadImage(tastingRef.id);

      if (photoUrl != null) {
        await tastingRef.update({'photoUrl': photoUrl});
      }

      // Si la cerveza NO tenía foto oficial, usar esta
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final beerDoc = await FirebaseFirestore.instance
            .collection('beers')
            .doc(beerId)
            .get();

        final currentBeerPhoto = beerDoc.data()?['photoUrl'];

        if (currentBeerPhoto == null || currentBeerPhoto.isEmpty) {
          await FirebaseFirestore.instance
              .collection('beers')
              .doc(beerId)
              .update({'photoUrl': photoUrl});
        }
      }

      // Registrar actividad
      await FirebaseFirestore.instance.collection('activities').add({
        'type': 'tasting',
        'actorUid': myUid,
        'targetIds': {'beerId': beerId, 'tastingId': tastingRef.id},
        'createdAt': FieldValue.serverTimestamp(),
        'public': true,
      });

      // Stats del usuario
      final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);
      final userSnap = await userRef.get();
      final stats = (userSnap.data()?['stats'] as Map<String, dynamic>?) ?? {};

      final int currentTastingsTotal =
          stats['tastingsTotal'] is num ? (stats['tastingsTotal'] as num).toInt() : 0;
      final int newTastingsTotal = currentTastingsTotal + 1;

      await userRef.set({
        'stats': {
          'tastingsTotal': FieldValue.increment(1),
          'tastings7d': FieldValue.increment(1),
        },
      }, SetOptions(merge: true));

      // Comprobar si hay nuevos galardones por degustaciones
      final newAwards = await AwardManager.checkAndGrantTastingAwards(
        uid: myUid,
        tastingsTotal: newTastingsTotal,
      );

      if (mounted && newAwards.isNotEmpty) {
        for (final award in newAwards) {
          await _showAwardDialog(award);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Degustacion registrada')),
        );
        context.go('/');
      }

    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showBeerSelector() async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar cerveza...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) async {
                      if (value.trim().isEmpty) {
                        setStateModal(() => results = []);
                        return;
                      }
                      final snap = await FirebaseFirestore.instance
                          .collection('beers')
                          .get();
                      setStateModal(() {
                        results = snap.docs
                            .where(
                              (d) => (d['name'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()),
                            )
                            .map((d) => {'id': d.id, 'name': d['name']})
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (results.isEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Registrar nueva cerveza"),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/cerveza/new');
                      },
                    ),
                  if (results.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final beer = results[index];
                          return ListTile(
                            title: Text(beer['name']),
                            onTap: () {
                              selectedBeer = beer;
                              Navigator.pop(context);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showVenueSelector() async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar local...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) async {
                      if (value.trim().isEmpty) {
                        setStateModal(() => results = []);
                        return;
                      }
                      final snap = await FirebaseFirestore.instance
                          .collection('venues')
                          .get();
                      setStateModal(() {
                        results = snap.docs
                            .where(
                              (d) => (d['name'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()),
                            )
                            .map((d) => {'id': d.id, 'name': d['name']})
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (results.isEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Registrar nuevo local"),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/local/new');
                      },
                    ),
                  if (results.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final venue = results[index];
                          return ListTile(
                            title: Text(venue['name']),
                            onTap: () {
                              selectedVenue = venue;
                              Navigator.pop(context);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

Future<void> _showAwardDialog(UnlockedAward award) async {
  if (!mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nuevo galardon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(award.imageUrl),
            ),
            const SizedBox(height: 12),
            Text(
              award.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text('Nivel ${award.level}'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vale'),
            ),
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar degustación"),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ListTile(
                title: Text(selectedBeer?['name'] ?? "Seleccionar cerveza"),
                trailing: const Icon(Icons.search),
                onTap: _showBeerSelector,
              ),
              ListTile(
                title: Text(selectedVenue?['name'] ?? "Seleccionar local"),
                trailing: const Icon(Icons.search),
                onTap: _showVenueSelector,
              ),
              const SizedBox(height: 16),
              const Text("Valoración:"),
              StarRating(
                rating: rating,
                onRatingChanged: (r) => setState(() => rating = r),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Descripción"),
              ),
              const SizedBox(height: 16),
              if (kIsWeb && _webImage != null)
                SizedBox(
                  height: 200, // altura máxima
                  child: Image.memory(_webImage!, fit: BoxFit.contain),
                )
              else if (!kIsWeb && _imageFile != null)
                SizedBox(
                  height: 200,
                  child: Image.file(_imageFile!, fit: BoxFit.contain),
                ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Subir foto"),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text("Marcar como favorita ⭐"),
                value: _isFavorite,
                onChanged: (val) => setState(() => _isFavorite = val ?? false),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _saveDegustacion,
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

class StarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final int starCount;

  const StarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.starCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(starCount, (index) {
          final starValue = index + 1;
          IconData icon;

          if (rating >= starValue) {
            icon = Icons.star;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }

          return GestureDetector(
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;

              // Detectar clic dentro de la estrella
              final localX = details.localPosition.dx;
              final width = 44.0; // tamaño del icono (coincide con size)
              final isLeftHalf = localX < width / 2;

              final newRating = isLeftHalf ? (index + 0.5) : (index + 1.0);
              onRatingChanged(newRating);
            },
            child: Icon(icon, color: Colors.amber, size: 44),
          );
        }),
      ),
    );
  }
}
