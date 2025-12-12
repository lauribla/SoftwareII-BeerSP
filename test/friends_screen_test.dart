import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beersp_demo/FriendsScreen.dart';

void main() {
  test('FriendsScreen es un StatefulWidget', () {
    const screen = FriendsScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('FriendsScreen.createState devuelve un State<FriendsScreen>', () {
    const screen = FriendsScreen();
    final state = screen.createState();
    expect(state, isA<State<FriendsScreen>>());
  });

  test('El estado de FriendsScreen actua como TickerProvider', () {
    const screen = FriendsScreen();
    final state = screen.createState();

    expect(state, isA<TickerProvider>());
  });
}
