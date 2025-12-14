import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beersp_demo/RecuperarContrasena.dart';

void main() {
  test('RecuperarContrasena es un StatefulWidget', () {
    const screen = RecuperarContrasena();
    expect(screen, isA<StatefulWidget>());
  });

  test('RecuperarContrasena.createState devuelve un State<RecuperarContrasena>', () {
    const screen = RecuperarContrasena();
    final state = screen.createState();
    expect(state, isA<State<RecuperarContrasena>>());
  });

test('RecuperarContrasena crea instancias distintas', () {
    const a = RecuperarContrasena();
    const b = RecuperarContrasena();
    expect(a, isNot(same(b)));
  });

  testWidgets('RecuperarContrasena se puede instanciar sin fallar', (tester) async {
    const screen = RecuperarContrasena();
    expect(screen, isNotNull);
  });

  testWidgets('Se puede envolver en un MaterialApp sin fallar al instanciarlo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Placeholder()),
    );
    expect(find.byType(Placeholder), findsOneWidget);
  });

  test('State implementa dispose()', () {
    final state = const RecuperarContrasena().createState();
    expect(state.dispose, isA<Function>());
  });
}
