import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class CrearLocalScreen extends StatefulWidget {
  const CrearLocalScreen({super.key});

  @override
  State<CrearLocalScreen> createState() => _CrearLocalScreenState();
}

class _CrearLocalScreenState extends State<CrearLocalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingLocation = false;

  Future<void> _useMyLocation() async {
    setState(() => _loadingLocation = true);

    try {
      // Pedir permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Permisos de ubicación denegados';
      }

      // Verificar si el servicio de ubicación está activado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'El GPS está desactivado. Actívalo en los ajustes del móvil.';
      }

      // Mostrar mensaje de que está obteniendo ubicación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obteniendo ubicación precisa... Espera unos segundos'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Intentar obtener ubicación con máxima precisión - ESPERAR MÁS TIEMPO
      Position? position;
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: false,
            timeLimit: const Duration(seconds: 30), // MÁS TIEMPO
          );

          // Si la precisión es muy mala, reintentar
          if (position.accuracy > 50 && attempts < maxAttempts - 1) {
            print('Intento ${attempts + 1}: Precisión mala (${position.accuracy}m). Reintentando...');
            attempts++;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          break;
        } catch (e) {
          attempts++;
          if (attempts >= maxAttempts) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (position == null) {
        throw 'No se pudo obtener la ubicación';
      }

      final latitude = position.latitude;
      final longitude = position.longitude;
      final accuracy = position.accuracy;

      print('Coordenadas exactas: $latitude, $longitude');
      print('Precisión: $accuracy metros');

      // Verificar si la precisión es aceptable
      if (accuracy > 100) {
        if (mounted) {
          final continuar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Precisión baja'),
              content: Text(
                'La precisión del GPS es de ${accuracy.toStringAsFixed(0)} metros.\n\n'
                '¿Quieres continuar de todos modos?\n\n'
                'Consejo: Sal al exterior y espera unos segundos para mejor precisión.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );

          if (continuar != true) {
            setState(() => _loadingLocation = false);
            return;
          }
        }
      }

      // Usar Nominatim con zoom máximo para precisión
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=19&addressdetails=1&accept-language=es';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FlutterVenuesApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};
        
        print('Datos de Nominatim: $address');

        String street = '';
        String city = '';
        String country = '';

        // Obtener número y calle
        final houseNumber = address['house_number'] ?? '';
        final road = address['road'] ?? 
                     address['street'] ?? 
                     address['pedestrian'] ?? 
                     address['path'] ?? '';

        // Construir dirección
        if (road.isNotEmpty && houseNumber.isNotEmpty) {
          street = '$road $houseNumber';
        } else if (road.isNotEmpty) {
          street = road;
        }

        // Ciudad
        city = address['city'] ?? 
               address['town'] ?? 
               address['village'] ?? 
               address['municipality'] ?? 
               address['suburb'] ?? '';

        // País
        country = address['country'] ?? '';

        print('Resultado final:');
        print('- Dirección: $street');
        print('- Ciudad: $city');
        print('- País: $country');

        // Rellenar campos
        setState(() {
          _addressCtrl.text = street;
          _cityCtrl.text = city;
          _countryCtrl.text = country;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ubicación obtenida${houseNumber.isEmpty ? ". Añade el número si falta." : ""}',
              ),
              backgroundColor: accuracy > 50 ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw 'Error al obtener dirección';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  Future<void> _saveVenue() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('venues').add({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local creado correctamente')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear local: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear local"),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre del local",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Ingresa un nombre' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: "Dirección",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: "Ciudad",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countryCtrl,
                      decoration: const InputDecoration(
                        labelText: "País",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // BOTONES FIJOS EN LA PARTE INFERIOR
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _loadingLocation ? null : _useMyLocation,
                      icon: _loadingLocation
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location, size: 30),
                      label: const Text(
                        'Usar ubicación',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveVenue,
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              "Guardar local",
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}