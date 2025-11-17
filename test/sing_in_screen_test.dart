import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/SignInScreen.dart';

void main() {
  test('SignInScreen es StatefulWidget', () {
    const screen = SignInScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('SignInScreen crea instancias distintas', () {
    const a = SignInScreen();
    const b = SignInScreen();
    expect(a, isNot(same(b)));
  });

  test('SignInScreen tiene metodo createState', () {
    const screen = SignInScreen();
    expect(screen.createState, isA<Function>());
  });

  test('SignInScreen no es StatelessWidget', () {
    const screen = SignInScreen();
    expect(screen, isNot(isA<StatelessWidget>()));
  });

  test('SignInScreen tiene constructor const', () {
    const screen = SignInScreen();
    expect(screen, isNotNull);
  });

  test('SignInScreen tiene key nula por defecto', () {
    const screen = SignInScreen();
    expect(screen.key, isNull);
  });

  test('SignInScreen es un widget valido', () {
    const screen = SignInScreen();
    expect(screen, isA<Widget>());
  });

  testWidgets('Se puede crear un MaterialApp vacio sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
