import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/BeerDetailScreen.dart';

void main() {

  test('BeerDetailScreen es un StatefulWidget', () {
    const screen = BeerDetailScreen(beerId: '123');
    expect(screen, isA<StatefulWidget>());
  });

  test('BeerDetailScreen requiere un beerId', () {
    const screen = BeerDetailScreen(beerId: 'cerveza_01');
    expect(screen.beerId, 'cerveza_01');
  });

  test('createState devuelve un State<BeerDetailScreen>', () {
    const screen = BeerDetailScreen(beerId: '123');
    final state = screen.createState();
    expect(state, isA<State<BeerDetailScreen>>());
  });

  test('BeerDetailScreen crea instancias distintas sin compartir estado', () {
    const a = BeerDetailScreen(beerId: '1');
    const b = BeerDetailScreen(beerId: '2');

    expect(a.beerId, '1');
    expect(b.beerId, '2');
    expect(a, isNot(same(b)));
  });

  test('BeerDetailScreen tiene un método dispose()', () {
    final state = const BeerDetailScreen(beerId: '123').createState();
    expect(state.dispose, isA<Function>());
  });
}
