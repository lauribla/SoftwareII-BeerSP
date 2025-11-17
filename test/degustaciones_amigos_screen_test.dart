import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/DegustacionesAmigosScreen.dart';

void main() {
  test('DegustacionesAmigosScreen es StatelessWidget', () {
    const screen = DegustacionesAmigosScreen();
    expect(screen, isA<StatelessWidget>());
  });

  testWidgets('Se construye sin fallar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DegustacionesAmigosScreen(),
      ),
    );
    expect(find.byType(DegustacionesAmigosScreen), findsOneWidget);
  });

  testWidgets('Tiene AppBar con el título correcto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DegustacionesAmigosScreen()),
    );
    expect(find.text("Degustaciones de amigos"), findsOneWidget);
  });

  testWidgets('Muestra un CircularProgressIndicator al iniciar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DegustacionesAmigosScreen()),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
