import 'package:flutter_test/flutter_test.dart';
import 'package:beersp_demo/main.dart';

import 'firebase_mock.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Usa Firebase fake
    FirebasePlatform.instance = FakeFirebasePlatform();
  });

  testWidgets('BeerSpApp se construye sin explotar', (tester) async {
    await tester.pumpWidget(const BeerSpApp());
    expect(find.byType(BeerSpApp), findsOneWidget);
  });
}
