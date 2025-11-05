import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? _selectedDob;
  String? _error;

  bool get _isAdult {
    if (_selectedDob == null) return false;
    final today = DateTime.now();
    final age = today.year - _selectedDob!.year;
    final hadBirthdayThisYear = (today.month > _selectedDob!.month) ||
        (today.month == _selectedDob!.month && today.day >= _selectedDob!.day);
    final realAge = hadBirthdayThisYear ? age : age - 1;
    return realAge >= 18;
  }

  void _continue() {
    if (_selectedDob == null) {
      setState(() => _error = "Selecciona tu fecha de nacimiento");
      return;
    }
    if (!_isAdult) {
      setState(() => _error = "Debes ser mayor de edad para registrarte");
      return;
    }

    // Si es adulto → continuar al registro
    context.push('/auth/signup', extra: _selectedDob);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _selectedDob == null
        ? "No seleccionada"
        : "${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("Verificación de edad")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Para continuar, necesitamos confirmar tu edad",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Mostrar DOB seleccionada
              Text("Fecha de nacimiento: $dobText"),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _pickDate,
                child: const Text("Seleccionar fecha"),
              ),
              const SizedBox(height: 30),

              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _selectedDob == null ? null : _continue,
                child: const Text("Continuar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
