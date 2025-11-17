import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/CrearLocalScreen.dart';

void main() {
  test('CrearLocalScreen es StatefulWidget', () {
    const screen = CrearLocalScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('createState devuelve State<CrearLocalScreen>', () {
    const screen = CrearLocalScreen();
    final state = screen.createState();
    expect(state, isA<State<CrearLocalScreen>>());
  });

  testWidgets('Se construye sin fallar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CrearLocalScreen(),
      ),
    );
    expect(find.byType(CrearLocalScreen), findsOneWidget);
  });

  testWidgets('Tiene AppBar con título', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CrearLocalScreen()),
    );
    expect(find.text("Crear local"), findsOneWidget);
  });

  testWidgets('Tiene cuatro TextFormField', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CrearLocalScreen()),
    );
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('Botón Guardar aparece', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CrearLocalScreen()),
    );
    expect(find.text("Guardar"), findsOneWidget);
  });
}
