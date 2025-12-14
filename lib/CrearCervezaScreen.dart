import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'award_manager.dart';


class CrearCervezaScreen extends StatefulWidget {
  const CrearCervezaScreen({super.key});

  @override
  State<CrearCervezaScreen> createState() => _CrearCervezaScreenState();
}

class _CrearCervezaScreenState extends State<CrearCervezaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _abvCtrl = TextEditingController();
  final _ibuCtrl = TextEditingController();
  final _countryController = TextEditingController(text: "🇪🇸 España");


  String style = 'IPA';
  String size = 'Pinta';
  String format = 'Botella';
  String color = 'Dorado claro';

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abvCtrl.dispose();
    _ibuCtrl.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        _countryController.text = "${country.flagEmoji} ${country.name}";
      },
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Buscar país',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _saveBeer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Guardamos en Firestore
      await FirebaseFirestore.instance.collection('beers').add({
        'name': _nameCtrl.text.trim(),
        'style': style,
        'originCountry': _countryController.text.trim(),
        'size': size,
        'format': format,
        'color': color,
        'abv': double.tryParse(_abvCtrl.text.trim()) ?? 0,
        'ibu': int.tryParse(_ibuCtrl.text.trim()) ?? 0,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // --- Galardon por crear cervezas ---
final userRef =
    FirebaseFirestore.instance.collection('users').doc(uid);

// Incrementar contador
await userRef.set({
  'stats': {
    'beersCreated': FieldValue.increment(1),
  }
}, SetOptions(merge: true));

// Leer valor actualizado
final userSnap = await userRef.get();
final stats = (userSnap.data()?['stats'] as Map<String, dynamic>?) ?? {};

final int beersCreated =
    stats['beersCreated'] is num
        ? (stats['beersCreated'] as num).toInt()
        : 0;

// Comprobar galardones
final newAwards = await AwardManager.checkAndGrantAwards(
  uid: uid,
  metric: 'beersCreated',
  value: beersCreated,
);

// Mostrar popup
if (mounted && newAwards.isNotEmpty) {
  for (final award in newAwards) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo galardón'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(award.imageUrl, height: 80),
            const SizedBox(height: 12),
            Text(award.name),
            Text('Nivel ${award.level}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vale'),
          ),
        ],
      ),
    );
  }
}


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerveza creada')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildDropdown(String label, String value, List<String> options, void Function(String?) onChanged) {
    return DropdownButtonFormField(
      value: value,
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear cerveza")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: "Nombre",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Introduce el nombre' : null,
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                "Estilo",
                style,
                ['Lager', 'IPA', 'APA', 'Stout', 'Saison', 'Porter', 'Pilsner', 'Weissbier', 'Sour Ale', 'Lambic', 'Amber Ale'],
                (v) => setState(() => style = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _countryController,
                readOnly: true,
                onTap: _pickCountry,
                decoration: InputDecoration(
                  labelText: "País",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Selecciona un país' : null,
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                "Tamaño",
                size,
                ['Pinta', 'Media pinta', 'Tercio'],
                (v) => setState(() => size = v!),
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                "Formato",
                format,
                ['Barril', 'Lata', 'Botella'],
                (v) => setState(() => format = v!),
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                "Color",
                color,
                ['Dorado claro', 'Amarillo dorado', 'Ambar claro', 'Marrón oscuro', 'Negro opaco'],
                (v) => setState(() => color = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _abvCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Alcohol %",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ibuCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "IBU",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _saveBeer,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
