import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/TopDegustaciones.dart';

void main() {
  test('TopDegustacionesScreen es StatelessWidget', () {
    const screen = TopDegustacionesScreen();
    expect(screen, isA<StatelessWidget>());
  });

  test('TopDegustacionesScreen crea instancias distintas', () {
    const a = TopDegustacionesScreen();
    const b = TopDegustacionesScreen();
    expect(a, isNot(same(b)));
  });

  test('TopDegustacionesScreen tiene constructor const', () {
    const screen = TopDegustacionesScreen();
    expect(screen, isNotNull);
  });

  test('TopDegustacionesScreen tiene metodo build', () {
    const screen = TopDegustacionesScreen();
    expect(screen.build, isA<Function>());
  });

  test('TopDegustacionesScreen tiene key nula por defecto', () {
    const screen = TopDegustacionesScreen();
    expect(screen.key, isNull);
  });

  test('TopDegustacionesScreen createElement produce un StatelessElement', () {
    const screen = TopDegustacionesScreen();
    final element = screen.createElement();
    expect(element, isA<StatelessElement>());
  });

  test('TopDegustacionesScreen es un widget valido', () {
    const screen = TopDegustacionesScreen();
    expect(screen, isA<Widget>());
  });

  testWidgets('MaterialApp vacio se crea sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
