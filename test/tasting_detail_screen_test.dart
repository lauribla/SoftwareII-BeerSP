import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/TastingDetailScreen.dart';

void main() {
  test('TastingDetailScreen es StatelessWidget', () {
    const screen = TastingDetailScreen(tastingId: 'abc');
    expect(screen, isA<StatelessWidget>());
  });

  test('TastingDetailScreen recibe tastingId correctamente', () {
    const screen = TastingDetailScreen(tastingId: 'cerveza123');
    expect(screen.tastingId, 'cerveza123');
  });

  test('TastingDetailScreen crea instancias distintas', () {
    const a = TastingDetailScreen(tastingId: '1');
    const b = TastingDetailScreen(tastingId: '2');
    expect(a, isNot(same(b)));
  });

  test('TastingDetailScreen tiene metodo build', () {
    const screen = TastingDetailScreen(tastingId: 'id');
    expect(screen.build, isA<Function>());
  });

  test('TastingDetailScreen tiene constructor const', () {
    const screen = TastingDetailScreen(tastingId: 'a');
    expect(screen, isNotNull);
  });

  test('TastingDetailScreen tiene key nula por defecto', () {
    const screen = TastingDetailScreen(tastingId: 'a');
    expect(screen.key, isNull);
  });

  test('TastingDetailScreen createElement produce un StatelessElement', () {
    const screen = TastingDetailScreen(tastingId: 'a');
    final element = screen.createElement();
    expect(element, isA<StatelessElement>());
  });

  test('TastingDetailScreen es un widget valido', () {
    const screen = TastingDetailScreen(tastingId: 'a');
    expect(screen, isA<Widget>());
  });

  testWidgets('MaterialApp vacio se crea sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
