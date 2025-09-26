import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BeerSp - Inicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel 1: Perfil resumido
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('Perfil resumido'),
                subtitle: const Text('Stats 7d + solicitudes de amistad'),
                trailing: TextButton(
                  onPressed: () {
                    // Navegar a perfil
                  },
                  child: const Text('Ver perfil'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Panel 2: Actividad de amigos
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    title: Text('Actividad de amigos'),
                    subtitle: Text('Últimas 5 actividades'),
                  ),
                  for (int i = 0; i < 5; i++)
                    const ListTile(
                      leading: Icon(Icons.local_drink),
                      title: Text('Actividad de ejemplo'),
                      subtitle: Text('Detalle...'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navegar a feed completo
                      },
                      child: const Text('Ver todas'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Panel 3: Favoritas
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    title: Text('Cervezas favoritas'),
                    subtitle: Text('Top 3 valoradas'),
                  ),
                  for (int i = 0; i < 3; i++)
                    const ListTile(
                      leading: Icon(Icons.star),
                      title: Text('Cerveza ejemplo'),
                      subtitle: Text('Estilo / País'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navegar a top degustaciones
                      },
                      child: const Text('Ver todas'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Panel 4: Galardones
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    title: Text('Últimos galardones'),
                    subtitle: Text('Máx. 5'),
                  ),
                  for (int i = 0; i < 5; i++)
                    const ListTile(
                      leading: Icon(Icons.emoji_events),
                      title: Text('Galardón ejemplo'),
                      subtitle: Text('Nivel alcanzado'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navegar a galardones completos
                      },
                      child: const Text('Ver todos'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
