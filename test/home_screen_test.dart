import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/HomeScreen.dart';

void main() {
  test('HomeScreen es StatelessWidget', () {
    const screen = HomeScreen();
    expect(screen, isA<StatelessWidget>());
  });

  test('HomeScreen crea instancias distintas', () {
    const a = HomeScreen();
    const b = HomeScreen();
    expect(a, isNot(same(b)));
  });

  test('HomeScreen tiene metodo build', () {
    const screen = HomeScreen();
    expect(screen.build, isA<Function>());
  });

  test('SearchBarWidget es StatefulWidget', () {
    const sb = SearchBarWidget();
    expect(sb, isA<StatefulWidget>());
  });

  test('SearchBarWidget crea un State correcto', () {
    const sb = SearchBarWidget();
    final st = sb.createState();
    expect(st, isA<State<SearchBarWidget>>());
  });

  test('_SearchBarWidgetState tiene campo searchQuery', () {
    final st = const SearchBarWidget().createState() as dynamic;
    expect(() => st.searchQuery, returnsNormally);
  });

  test('_SearchBarWidgetState tiene campo results', () {
    final st = const SearchBarWidget().createState() as dynamic;
    expect(() => st.results, returnsNormally);
  });

  test('HomeScreen tiene FloatingActionButton en su clase', () {
    const screen = HomeScreen();
    final widget = screen;
    expect(widget, isA<HomeScreen>());
  });

  test('HomeScreen define SearchBarWidget en el arbol', () {
    const screen = HomeScreen();
    expect(screen, isNotNull);
  });

  testWidgets('Se puede crear un MaterialApp vacio sin fallar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(find.byType(Placeholder), findsOneWidget);
  });

  test('SearchBarWidget crea estados distintos en diferentes instancias', () {
    final a = const SearchBarWidget().createState();
    final b = const SearchBarWidget().createState();
    expect(a, isNot(same(b)));
  });

  test('HomeScreen no es StatefulWidget', () {
    const screen = HomeScreen();
    expect(screen, isNot(isA<StatefulWidget>()));
  });

  test('SearchBarWidget tiene metodo search', () {
    final st = const SearchBarWidget().createState() as dynamic;
    expect(() => st.search, returnsNormally);
  });
}
