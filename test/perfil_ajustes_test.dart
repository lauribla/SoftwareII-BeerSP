import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/PerfilAjustes.dart';

void main() {
  test('PerfilAjustesScreen es StatefulWidget', () {
    const screen = PerfilAjustesScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('PerfilAjustesScreen crea instancias distintas', () {
    const a = PerfilAjustesScreen();
    const b = PerfilAjustesScreen();
    expect(a, isNot(same(b)));
  });

  test('PerfilAjustesScreen tiene metodo createState', () {
    const screen = PerfilAjustesScreen();
    expect(screen.createState, isA<Function>());
  });

  test('PerfilAjustesScreen no es StatelessWidget', () {
    const screen = PerfilAjustesScreen();
    expect(screen, isNot(isA<StatelessWidget>()));
  });

  test('PerfilAjustesScreen tiene constructor const', () {
    const screen = PerfilAjustesScreen();
    expect(screen, isNotNull);
  });

  test('PerfilAjustesScreen tiene key nula por defecto', () {
    const screen = PerfilAjustesScreen();
    expect(screen.key, isNull);
  });

  testWidgets('Se puede crear un MaterialApp vacio sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });

  test('PerfilAjustesScreen es un widget valido', () {
    const screen = PerfilAjustesScreen();
    expect(screen, isA<Widget>());
  });
}
