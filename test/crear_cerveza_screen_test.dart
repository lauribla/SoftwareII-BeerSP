import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/CrearCervezaScreen.dart';

void main() {

  test('CrearCervezaScreen es un StatefulWidget', () {
    const screen = CrearCervezaScreen();
    expect(screen, isA<StatefulWidget>());
  });

  test('createState devuelve un State<CrearCervezaScreen>', () {
    const screen = CrearCervezaScreen();
    final state = screen.createState();
    expect(state, isA<State<CrearCervezaScreen>>());
  });

  test('CrearCervezaScreen permite instanciar varias pantallas distintas', () {
    const a = CrearCervezaScreen();
    const b = CrearCervezaScreen();
    expect(a, isNot(same(b)));
  });

  test('createState contiene campos mutables básicos sin lanzar errores', () {
    final state = const CrearCervezaScreen().createState()
        as dynamic; 

    expect(state.style, isA<String>());
    expect(state.size, isA<String>());
    expect(state.format, isA<String>());
    expect(state.color, isA<String>());
  });

  test('CrearCervezaScreen implementa dispose()', () {
    final state = const CrearCervezaScreen().createState();
    expect(state.dispose, isA<Function>());
  });
}
