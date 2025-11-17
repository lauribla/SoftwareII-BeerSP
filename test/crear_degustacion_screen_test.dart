import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/CrearDegustacionScreen.dart';

void main() {
  test('CrearDegustacionScreen es un StatefulWidget', () {
    const screen = CrearDegustacionScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('createState devuelve un State<CrearDegustacionScreen>', () {
    const screen = CrearDegustacionScreen();
    final state = screen.createState();
    expect(state, isA<State<CrearDegustacionScreen>>());
  });

  test('CrearDegustacionScreen permite instancias independientes', () {
    const a = CrearDegustacionScreen();
    const b = CrearDegustacionScreen();
    expect(a, isNot(same(b)));
  });

  test('State implementa dispose()', () {
    final state = const CrearDegustacionScreen().createState();
    expect(state.dispose, isA<Function>());
  });
}
