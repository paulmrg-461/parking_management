import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/locale_cubit.dart';

import '../../helpers/fake_key_value_store.dart';

void main() {
  test('Success: the selected language is persisted and restored', () async {
    final store = FakeKeyValueStore();
    final cubit = LocaleCubit(store);
    addTearDown(cubit.close);

    await cubit.select(const Locale('en'));
    final restored = LocaleCubit(store)..restore();
    addTearDown(restored.close);

    expect(restored.state, const Locale('en'));
  });

  test('Failure: the system option clears the explicit language', () async {
    final store = FakeKeyValueStore();
    final cubit = LocaleCubit(store);
    addTearDown(cubit.close);
    await cubit.select(const Locale('es'));

    await cubit.select(null);
    final restored = LocaleCubit(store)..restore();
    addTearDown(restored.close);

    expect(restored.state, isNull);
  });

  test('Security: an unknown stored value follows the system', () {
    final store = FakeKeyValueStore();
    store.put('preferences', 'locale', 'fr');
    final cubit = LocaleCubit(store)..restore();
    addTearDown(cubit.close);

    expect(cubit.state, isNull);
  });
}
