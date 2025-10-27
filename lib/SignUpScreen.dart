import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  final DateTime dob; // viene desde AgeGateScreen (obligatorio aquí)

  const SignUpScreen({super.key, required this.dob});

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
  final _countryCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String? _selectedGender;
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

      // 2. Guardar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'dob': widget.dob.toIso8601String().split('T').first, // fecha nacimiento
        'isAdult': true, // validado previamente en AgeGate
        'displayName': _displayNameCtrl.text.trim(),
        'surname':
            _surnameCtrl.text.isNotEmpty ? _surnameCtrl.text.trim() : null,
        'gender': _selectedGender ?? '', // nuevo campo
        'country': _countryCtrl.text.trim(), // nuevo campo
        'location': _locationCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Relaciones y listas iniciales
        'friends': [],
        'tastings': [],
        'badges': [],
        // Estadísticas resumen
        'stats': {
          'tastingsTotal': 0,
          'tastings7d': 0,
          'venuesTotal': 0,
          'badgesCount': 0,
        },
      });

      // 3. Enviar correo de verificación
    await cred.user!.sendEmailVerification();

    // 4. Mostrar aviso al usuario
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Te hemos enviado un correo de verificación a ${_emailCtrl.text.trim()}. '
            'Por favor revisa tu bandeja de entrada antes de iniciar sesión.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Opcional: cerrar sesión temporalmente
      await FirebaseAuth.instance.signOut();

      // Redirigir al login o pantalla de inicio de sesión
      context.go('/auth/singin');
    }
        } finally {
          setState(() => _loading = false);
        }
      }

  @override
  Widget build(BuildContext context) {
    final dobText =
        "${widget.dob.day}/${widget.dob.month}/${widget.dob.year}";

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                "Fecha de nacimiento: $dobText",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Email y contraseña
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
                decoration:
                    const InputDecoration(labelText: 'Nombre a mostrar'),
              ),
              TextFormField(
                controller: _surnameCtrl,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),

              // Nuevo: selector de género
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: 'Género'),
                items: const [
                  DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                  DropdownMenuItem(value: 'Prefiero no decirlo', child: Text('Prefiero no decirlo')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
              ),

              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: 'País'),
              ),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Ubicación (ciudad)'),
              ),
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio / Presentación'),
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
