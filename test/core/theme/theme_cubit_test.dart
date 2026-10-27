import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/storage/key_value_store.dart';
import 'package:parking_management/core/theme/theme_cubit.dart';

import '../../helpers/fake_key_value_store.dart';

class _FailingStore implements KeyValueStore {
  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Object? get(String box, String key) => null;

  @override
  Future<void> put(String box, String key, Object? value) async =>
      throw const ValidationFailure('read-only');

  @override
  Future<void> remove(String box, String key) async {}
}

void main() {
  test('Success: restores the stored appearance', () {
    final cubit = ThemeCubit(
      FakeKeyValueStore()..values['preferences/theme_mode'] = 'dark',
    );
    addTearDown(cubit.close);

    cubit.restore();

    expect(cubit.state, ThemeMode.dark);
  });

  test('Failure: an unknown value falls back to the system theme', () {
    final cubit = ThemeCubit(
      FakeKeyValueStore()..values['preferences/theme_mode'] = 'sepia',
    );
    addTearDown(cubit.close);

    cubit.restore();

    expect(cubit.state, ThemeMode.system);
  });

  test('Security: a read-only store still applies the choice', () async {
    final cubit = ThemeCubit(_FailingStore());
    addTearDown(cubit.close);

    await cubit.select(ThemeMode.light);

    expect(cubit.state, ThemeMode.light);
  });

  test('Success: selecting persists the wire value', () async {
    final store = FakeKeyValueStore();
    final cubit = ThemeCubit(store);
    addTearDown(cubit.close);

    await cubit.select(ThemeMode.dark);

    expect(store.values['preferences/theme_mode'], 'dark');
  });
}
