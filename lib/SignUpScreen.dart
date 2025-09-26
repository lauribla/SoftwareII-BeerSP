import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  final DateTime? dob; // la fecha de nacimiento viene desde AgeGateScreen

  const SignUpScreen({super.key, this.dob});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1. Crear usuario en Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2. Crear documento en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'dob': widget.dob?.toIso8601String().split('T').first,
        'isAdult': true,
        'displayName': _displayNameCtrl.text.trim(),
        'surname': _surnameCtrl.text.isNotEmpty ? _surnameCtrl.text.trim() : null,
        'location': _locationCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'stats': {
          'tastings7d': 0,
          'newVenues7d': 0,
          'badgesCount': 0,
        },
      });

      // 3. Verificación de correo
      await cred.user!.sendEmailVerification();

      // 4. Navegar al Home
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v!.isEmpty ? 'Introduce un email' : null,
              ),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Introduce un username' : null,
              ),
              TextFormField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre a mostrar'),
              ),
              TextFormField(
                controller: _surnameCtrl,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Ubicación'),
              ),
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
