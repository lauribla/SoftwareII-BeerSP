import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bienvenido a BeerSp")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Accede a tu cuenta o regístrate para empezar",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),

              // Botón de iniciar sesión
              ElevatedButton.icon(
                onPressed: () => context.push('/auth/signin'),
                icon: const Icon(Icons.login),
                label: const Text("Iniciar sesión"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),

              // Botón de registrarse
              ElevatedButton.icon(
                onPressed: () => context.push('/auth/agegate'),
                icon: const Icon(Icons.person_add),
                label: const Text("Registrarse"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
