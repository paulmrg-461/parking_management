import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/security/auto_lock_cubit.dart';

import '../../helpers/fake_key_value_store.dart';

void main() {
  late DateTime now;
  AutoLockCubit cubit(FakeKeyValueStore store) => AutoLockCubit(
    store,
    clock: () => now,
  );

  setUp(() => now = DateTime(2026, 11, 5, 12));

  test('Success: locks after the idle timeout and unlocks on demand', () {
    final store = FakeKeyValueStore();
    final subject = cubit(store);
    addTearDown(subject.close);

    now = now.add(const Duration(minutes: 4));
    subject.check();
    expect(subject.state, isFalse);

    now = now.add(const Duration(minutes: 1));
    subject.check();
    expect(subject.state, isTrue);

    subject.unlock();
    expect(subject.state, isFalse);
  });

  test('Success: any activity resets the idle clock', () {
    final store = FakeKeyValueStore();
    final subject = cubit(store);
    addTearDown(subject.close);

    now = now.add(const Duration(minutes: 4));
    subject.recordActivity();
    now = now.add(const Duration(minutes: 4));
    subject.check();
    expect(subject.state, isFalse);

    now = now.add(const Duration(minutes: 1));
    subject.check();
    expect(subject.state, isTrue);
  });

  test('Failure: disabled never locks', () async {
    final store = FakeKeyValueStore();
    final subject = cubit(store);
    addTearDown(subject.close);

    await subject.select(0);
    now = now.add(const Duration(hours: 2));
    subject.check();
    subject.lockNow();
    expect(subject.state, isFalse);
  });

  test('Security: the preference persists and invalid values fall back', () async {
    final store = FakeKeyValueStore();
    final subject = cubit(store);
    addTearDown(subject.close);
    await subject.select(15);
    expect(store.get('preferences', 'auto_lock_minutes'), 15);

    final restored = cubit(store)..restore();
    addTearDown(restored.close);
    expect(restored.minutes, 15);

    store.values['preferences/auto_lock_minutes'] = 999;
    final invalid = AutoLockCubit(store, clock: () => now)..restore();
    addTearDown(invalid.close);
    expect(invalid.minutes, 5);
  });
}
