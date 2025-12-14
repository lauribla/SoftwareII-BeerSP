import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VenueDetailScreen extends StatefulWidget {
  final String venueId;

  const VenueDetailScreen({
    super.key,
    required this.venueId,
  });

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  double? _latitude;
  double? _longitude;
  bool _loadingCoordinates = true;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    try {
      final venueDoc = await FirebaseFirestore.instance
          .collection('venues')
          .doc(widget.venueId)
          .get();

      if (!venueDoc.exists) return;

      final venue = venueDoc.data()!;
      final address = venue['address'] ?? '';
      final city = venue['city'] ?? '';
      final country = venue['country'] ?? '';

      if (address.isEmpty && city.isEmpty) {
        setState(() => _loadingCoordinates = false);
        return;
      }

      // Construir query para Nominatim
      final query = '$address, $city, $country'.trim();

      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'FlutterVenuesApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          setState(() {
            _latitude = double.parse(data[0]['lat']);
            _longitude = double.parse(data[0]['lon']);
            _loadingCoordinates = false;
          });
        } else {
          setState(() => _loadingCoordinates = false);
        }
      } else {
        setState(() => _loadingCoordinates = false);
      }
    } catch (e) {
      print('Error cargando coordenadas: $e');
      setState(() => _loadingCoordinates = false);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadVenue() {
    return FirebaseFirestore.instance
        .collection('venues')
        .doc(widget.venueId)
        .get();
  }

  Widget _buildStaticMap() {
    if (_loadingCoordinates) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_latitude == null || _longitude == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 60, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Ubicación no disponible',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Usar MapTiler (servicio gratuito de mapas estáticos)
    final zoom = 15;
    final mapUrl =
        'https://api.maptiler.com/maps/streets/static/$_longitude,$_latitude,$zoom/600x400.png?key=get_your_own_OpIi9ZULNHzrESv6T2vL';

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              mapUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                // Fallback: mostrar info de ubicación en caso de error
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blue[100]!, Colors.blue[50]!],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 80, color: Colors.blue[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Mapa no disponible',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${_latitude!.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        Text(
                          'Lon: ${_longitude!.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Marcador personalizado en el centro
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Colors.red[600],
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del local"),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadVenue(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Local no encontrado"));
          }

          final venue = snapshot.data!.data()!;
          final name = venue['name'] ?? 'Sin nombre';
          final address = venue['address'] ?? '—';
          final city = venue['city'] ?? '—';
          final country = venue['country'] ?? '—';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mapa estático
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildStaticMap(),
                ),

                const SizedBox(height: 24),

                // Nombre del local
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Información del local
                _InfoRow(
                  icon: Icons.location_on,
                  label: 'Dirección',
                  value: address,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.location_city,
                  label: 'Ciudad',
                  value: city,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.flag,
                  label: 'País',
                  value: country,
                ),

                const SizedBox(height: 24),

                // Coordenadas (opcional, para debug)
                if (_latitude != null && _longitude != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pin_drop, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${_latitude!.toStringAsFixed(6)}, Lon: ${_longitude!.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 227, 210),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}