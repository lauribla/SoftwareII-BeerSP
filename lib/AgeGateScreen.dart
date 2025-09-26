import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? dob;

  bool get isAdult {
    if (dob == null) return false;
    final now = DateTime.now();
    int years = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      years--;
    }
    return years >= 18;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de edad')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => dob = picked);
                }
              },
              child: Text(
                dob == null
                    ? 'Selecciona tu fecha de nacimiento'
                    : dob!.toIso8601String().split('T').first,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isAdult && dob != null
                  ? () => context.go('/auth/signup', extra: dob)
                  : null,
              child: const Text('Continuar'),
            ),
            if (dob != null && !isAdult)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Debes ser mayor de 18 años para usar BeerSp.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
