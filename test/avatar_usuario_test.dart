import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:beersp_demo/AvatarUsuario.dart';

void main() {

  test('AvatarUsuario es un StatelessWidget', () {
    const avatar = AvatarUsuario();
    expect(avatar, isA<StatelessWidget>());
  });

  test('AvatarUsuario acepta un userId opcional', () {
    const avatar = AvatarUsuario(userId: "123");
    expect(avatar.userId, "123");
  });

  test('AvatarUsuario acepta un radius custom', () {
    const avatar = AvatarUsuario(radius: 40);
    expect(avatar.radius, 40);
  });

  test('AvatarUsuario tiene valores por defecto válidos', () {
    const avatar = AvatarUsuario();
    expect(avatar.userId, isNull);
    expect(avatar.radius, 20);
  });

  test('AvatarUsuario permite múltiples instancias independientes', () {
    const a = AvatarUsuario(userId: "1");
    const b = AvatarUsuario(userId: "2");

    expect(a.userId, "1");
    expect(b.userId, "2");
    expect(a, isNot(same(b)));
  });
}
