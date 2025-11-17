import 'package:flutter_test/flutter_test.dart';
import 'package:beersp_demo/FriendsScreen.dart';
import 'package:flutter/material.dart';

void main() {
  test('FriendsScreen es un StatefulWidget', () {
    const screen = FriendsScreen();
    expect(screen, isA<StatefulWidget>());
  });
}
