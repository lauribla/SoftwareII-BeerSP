import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/SignUpScreen.dart';

void main() {
  test('SignUpScreen es StatefulWidget', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    expect(screen, isA<StatefulWidget>());
  });

  test('SignUpScreen recibe un dob obligatorio', () {
    final dob = DateTime(1999, 5, 10);
    final screen = SignUpScreen(dob: dob);
    expect(screen.dob, dob);
  });

  test('SignUpScreen crea instancias distintas', () {
    final a = SignUpScreen(dob: DateTime(2000, 1, 1));
    final b = SignUpScreen(dob: DateTime(2001, 2, 2));
    expect(a, isNot(same(b)));
  });

  test('createState devuelve un State valido', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    final state = screen.createState();
    expect(state, isA<State<SignUpScreen>>());
  });

  test('SignUpScreen no es StatelessWidget', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    expect(screen, isNot(isA<StatelessWidget>()));
  });

  test('SignUpScreen tiene metodo createState', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    expect(screen.createState, isA<Function>());
  });

  test('SignUpScreen tiene constructor valido', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    expect(screen, isNotNull);
  });

  test('SignUpScreen tiene key nula por defecto', () {
    final screen = SignUpScreen(dob: DateTime(2000, 1, 1));
    expect(screen.key, isNull);
  });

  testWidgets('MaterialApp vacio se crea sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
