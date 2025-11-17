import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/TastingDetailScreen.dart';

void main() {
  test('TastingDetailScreen es StatelessWidget', () {
    const screen = TastingDetailScreen(beerId: 'abc');
    expect(screen, isA<StatelessWidget>());
  });

  test('TastingDetailScreen recibe beerId correctamente', () {
    const screen = TastingDetailScreen(beerId: 'cerveza123');
    expect(screen.beerId, 'cerveza123');
  });

  test('TastingDetailScreen crea instancias distintas', () {
    const a = TastingDetailScreen(beerId: '1');
    const b = TastingDetailScreen(beerId: '2');
    expect(a, isNot(same(b)));
  });

  test('TastingDetailScreen tiene metodo build', () {
    const screen = TastingDetailScreen(beerId: 'id');
    expect(screen.build, isA<Function>());
  });

  test('TastingDetailScreen tiene constructor const', () {
    const screen = TastingDetailScreen(beerId: 'a');
    expect(screen, isNotNull);
  });

  test('TastingDetailScreen tiene key nula por defecto', () {
    const screen = TastingDetailScreen(beerId: 'a');
    expect(screen.key, isNull);
  });

  test('TastingDetailScreen createElement produce un StatelessElement', () {
    const screen = TastingDetailScreen(beerId: 'a');
    final element = screen.createElement();
    expect(element, isA<StatelessElement>());
  });

  test('TastingDetailScreen es un widget valido', () {
    const screen = TastingDetailScreen(beerId: 'a');
    expect(screen, isA<Widget>());
  });

  testWidgets('MaterialApp vacio se crea sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
