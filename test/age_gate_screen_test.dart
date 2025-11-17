import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/AgeGateScreen.dart';

void main() {
  test('AgeGateScreen es un StatefulWidget', () {
    const screen = AgeGateScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('createState devuelve un State<AgeGateScreen>', () {
    const screen = AgeGateScreen();
    final state = screen.createState();
    expect(state, isA<State<AgeGateScreen>>());
  });

  test('AgeGateScreen permite instanciar varias pantallas sin problemas', () {
    const a = AgeGateScreen();
    const b = AgeGateScreen();
    expect(a, isNot(same(b)));
  });

}
