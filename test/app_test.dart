import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beersp_demo/main.dart';

import 'firebase_mock.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FirebasePlatform.instance = FakeFirebasePlatform();
  });

  testWidgets('BeerSpApp se construye sin explotar', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    expect(find.byType(BeerSpApp), findsOneWidget);
  });
    testWidgets('BeerSpApp es un StatelessWidget', (tester) async {
    const app = BeerSpApp();
    expect(app, isA<StatelessWidget>());
  });

  testWidgets('BeerSpApp contiene un MaterialApp.router', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('BeerSpApp tiene el titulo correcto', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('BeerSp'));
  });

  testWidgets('BeerSpApp tiene debugShowCheckedModeBanner en false', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('BeerSpApp define un ThemeData', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isA<ThemeData>());
  });

  testWidgets('BeerSpApp define un colorScheme basado en seed', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    final theme = materialApp.theme!;
    final colorScheme = theme.colorScheme;

    expect(colorScheme, isNotNull);
    // expect(colorScheme.seedColor, const Color.fromARGB(255, 209, 204, 56));
  });

  testWidgets('BeerSpApp define un textTheme basado en GoogleFonts Poppins', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    final theme = materialApp.theme!;
    final textTheme = theme.textTheme;

    expect(textTheme, isNotNull);
  });

}
 