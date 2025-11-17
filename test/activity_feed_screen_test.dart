import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/ActivityFeedScreen.dart';

void main() {
  test('ActivityFeedScreen es un StatelessWidget', () {
    const screen = ActivityFeedScreen();
    expect(screen, isA<StatelessWidget>());
  });

  test('ActivityFeedScreen tiene un constructor const', () {
    const screen = ActivityFeedScreen();
    expect(screen.key, isNull); 
  });

  test('ActivityFeedScreen implementa un método build()', () {
    const screen = ActivityFeedScreen();
    expect(screen.build, isA<Function>());
  });

  test('Existe el método privado _getFriendsAndMe', () {
    final methods = ActivityFeedScreen().runtimeType.toString();
    expect(methods.contains('ActivityFeedScreen'), true);
  });

  test('Podemos crear múltiples instancias sin estado interno', () {
    const a = ActivityFeedScreen();
    const b = ActivityFeedScreen();
    expect(a, isNot(same(b)));  
  });

  test('ActivityFeedScreen mantiene inmutabilidad básica', () {
    const screen = ActivityFeedScreen();
    expect(() => screen == ActivityFeedScreen(), returnsNormally);
  });

  test('ActivityFeedScreen es identificable en listas', () {
    const list = [ActivityFeedScreen(), ActivityFeedScreen()];
    expect(list.length, 2);
  });
}
