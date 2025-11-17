import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/AuthGateScreen.dart';

void main() {

  test('AuthGateScreen es un StatelessWidget', () {
    const screen = AuthGateScreen();
    expect(screen, isA<StatelessWidget>());
  });

  testWidgets('AuthGateScreen se construye sin explotar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthGateScreen(),
      ),
    );

    expect(find.byType(AuthGateScreen), findsOneWidget);
  });

  testWidgets('AuthGateScreen tiene un AppBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Bienvenido a BeerSp'), findsOneWidget);
  });

  testWidgets('AuthGateScreen muestra el texto explicativo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    expect(
      find.text("Accede a tu cuenta o regístrate para empezar"),
      findsOneWidget,
    );
  });

  testWidgets('AuthGateScreen tiene botón de iniciar sesión', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    expect(find.text("Iniciar sesión"), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
  });

  testWidgets('AuthGateScreen tiene botón de registrarse', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthGateScreen()),
    );

    expect(find.text("Registrarse"), findsOneWidget);
    expect(find.byIcon(Icons.person_add), findsOneWidget);
  });
}
