import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/NotificacionesScreen.dart';

void main() {
  test('NotificacionesScreen es StatefulWidget', () {
    const screen = NotificacionesScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('NotificacionesScreen crea instancias distintas', () {
    const a = NotificacionesScreen();
    const b = NotificacionesScreen();
    expect(a, isNot(same(b)));
  });

  test('NotificacionesScreen no es StatelessWidget', () {
    const screen = NotificacionesScreen();
    expect(screen, isNot(isA<StatelessWidget>()));
  });

  testWidgets('Se puede crear un MaterialApp vacio sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });

  test('NotificacionesScreen tiene metodo createState', () {
    const screen = NotificacionesScreen();
    expect(screen.createState, isA<Function>());
  });

  test('NotificacionesScreen tiene constructor const', () {
    const screen = NotificacionesScreen();
    expect(screen, isNotNull);
  });

  test('NotificacionesScreen puede usarse en un widget tree sin instanciarlo', () {
    const screen = NotificacionesScreen();
    expect(screen.key, isNull);
  });
}
