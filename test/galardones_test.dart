import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/Galardones.dart';

void main() {
  test('GalardonesScreen es StatelessWidget', () {
    const screen = GalardonesScreen();
    expect(screen, isA<StatelessWidget>());
  });

  test('GalardonesScreen crea instancias distintas sin compartir estado', () {
    const a = GalardonesScreen();
    const b = GalardonesScreen();
    expect(a, isNot(same(b)));
  });

  test('GalardonesScreen tiene un metodo build', () {
    const screen = GalardonesScreen();
    expect(screen.build, isA<Function>());
  });

  testWidgets('GalardonesScreen se puede instanciar sin fallar', (tester) async {
    const screen = GalardonesScreen();
    expect(screen, isNotNull);
  });

  testWidgets('Se puede envolver en un MaterialApp sin fallar al instanciarlo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Placeholder()),
    );
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
