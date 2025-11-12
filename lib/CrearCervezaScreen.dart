import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class CrearCervezaScreen extends StatefulWidget {
  const CrearCervezaScreen({super.key});

  @override
  State<CrearCervezaScreen> createState() => _CrearCervezaScreenState();
}

class _CrearCervezaScreenState extends State<CrearCervezaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String style = 'IPA';
  String country = 'España';
  String size = 'Pinta';
  String format = 'Botella';
  String color = 'Dorado claro';
  final _abvCtrl = TextEditingController();
  final _ibuCtrl = TextEditingController();

  bool _loading = false;

  Future<void> _saveBeer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('beers').add({
        'name': _nameCtrl.text.trim(),
        'style': style,
        'originCountry': country,
        'size': size,
        'format': format,
        'color': color,
        'abv': double.tryParse(_abvCtrl.text.trim()) ?? 0,
        'ibu': int.tryParse(_ibuCtrl.text.trim()) ?? 0,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerveza creada')),
        );
        context.pop();
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
      appBar: AppBar(title: const Text("Crear cerveza")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nombre")),
              DropdownButtonFormField(
                value: style,
                items: ['Lager', 'IPA', 'APA', 'Stout', 'Saison', 'Porter', 'Pilsner', 'Weissbier', 'Sour Ale', 'Lambic', 'Amber Ale']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => style = v!,
                decoration: const InputDecoration(labelText: "Estilo"),
              ),
              DropdownButtonFormField(
                value: country,
                items: ['España', 'Alemania', 'Bélgica', 'USA', 'Reino Unido']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => country = v!,
                decoration: const InputDecoration(labelText: "País"),
              ),
              DropdownButtonFormField(
                value: size,
                items: ['Pinta', 'Media pinta', 'Tercio']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => size = v!,
                decoration: const InputDecoration(labelText: "Tamaño"),
              ),
              DropdownButtonFormField(
                value: format,
                items: ['Barril', 'Lata', 'Botella']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => format = v!,
                decoration: const InputDecoration(labelText: "Formato"),
              ),
              DropdownButtonFormField(
                value: color,
                items: ['Dorado claro','Ambar claro','Marrón oscuro','Negro opaco']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => color = v!,
                decoration: const InputDecoration(labelText: "Color"),
              ),
              TextFormField(controller: _abvCtrl, decoration: const InputDecoration(labelText: "Alcohol %"), keyboardType: TextInputType.number),
              TextFormField(controller: _ibuCtrl, decoration: const InputDecoration(labelText: "IBU"), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _saveBeer,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
