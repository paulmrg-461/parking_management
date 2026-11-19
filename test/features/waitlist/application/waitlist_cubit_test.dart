import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/waitlist/application/waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_settings.dart';

import '../../../helpers/fake_waitlist_repository.dart';

WaitlistEntry _entry(int id, {String status = 'waiting'}) => WaitlistEntry(
  id: id,
  plate: 'ABC10$id',
  categoryId: 2,
  categoryName: 'car',
  customerName: 'Ana',
  customerPhone: '300111223$id',
  status: waitlistStatusFrom(status),
  waitUntil: DateTime.utc(2026, 1, 1, 15),
  holdMinutes: 60,
  position: id,
  createdAt: DateTime.utc(2026, 1, 1, 10),
);

void main() {
  test('Success: load emits loading then loaded', () async {
    final repository = FakeWaitlistRepository()
      ..entries = [_entry(1)]
      ..settings = const WaitlistSettings(
        enabled: true,
        claimMinutes: 20,
        maxEntries: 10,
      );
    final cubit = WaitlistCubit(repository);
    final states = <WaitlistState>[];
    cubit.stream.listen(states.add);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<WaitlistLoading>());
    final loaded = states.last as WaitlistLoaded;
    expect(loaded.entries.single.plate, 'ABC101');
    expect(loaded.settings?.claimMinutes, 20);
  });

  test('Failure: load failure emits the failure state', () async {
    final cubit = WaitlistCubit(
      FakeWaitlistRepository()..listError = const NetworkFailure('offline'),
    );

    await cubit.load();

    expect(cubit.state, isA<WaitlistFailure>());
  });

  test('Success: claiming refreshes the list', () async {
    final repository = FakeWaitlistRepository()..entries = [_entry(1)];
    final cubit = WaitlistCubit(repository);
    await cubit.load();

    final reservation = await cubit.claim(1);

    expect(reservation?.plate, 'ABC101');
    expect(repository.claimed, [1]);
    final loaded = cubit.state as WaitlistLoaded;
    expect(loaded.submission, isA<SubmissionSucceeded>());
  });

  test('Failure: a failing removal keeps the rows and reports it', () async {
    final repository = FakeWaitlistRepository()
      ..entries = [_entry(1), _entry(2)]
      ..actionError = const ValidationFailure(
        'Forbidden',
        'AdminRequiredError',
      );
    final cubit = WaitlistCubit(repository);
    await cubit.load();

    await cubit.remove(1);

    final loaded = cubit.state as WaitlistLoaded;
    expect(loaded.entries, hasLength(2));
    expect(loaded.submission, isA<SubmissionFailed>());
  });

  test('Success: saving the settings calls the repository', () async {
    final repository = FakeWaitlistRepository();
    final cubit = WaitlistCubit(repository);
    await cubit.load();

    await cubit.saveSettings(
      const WaitlistSettings(enabled: true, claimMinutes: 30, maxEntries: 5),
    );

    expect(repository.saved.single.enabled, isTrue);
    expect((cubit.state as WaitlistLoaded).settings?.maxEntries, 5);
  });
}
