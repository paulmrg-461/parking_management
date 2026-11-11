import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/waitlist/application/public_waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/domain/entities/public_waitlist.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';

import '../../../helpers/fake_public_waitlist_repository.dart';

DateTime _waitUntil() => DateTime.now().add(const Duration(hours: 3));

void main() {
  test('Success: a disabled waitlist renders nothing', () async {
    final cubit = PublicWaitlistCubit(
      FakePublicWaitlistRepository()
        ..infoValue = const PublicWaitlistInfo(
          enabled: false,
          claimMinutes: 15,
          notifyChannel: WaitlistChannel.screen,
        ),
    );

    await cubit.load(1);

    expect(cubit.state, isA<PublicWaitlistUnavailable>());
  });

  test('Success: a lot without settings renders nothing', () async {
    final cubit = PublicWaitlistCubit(
      FakePublicWaitlistRepository()..infoValue = null,
    );

    await cubit.load(1);

    expect(cubit.state, isA<PublicWaitlistUnavailable>());
  });

  test('Success: joining stores the entry and the phone', () async {
    final repository = FakePublicWaitlistRepository();
    final cubit = PublicWaitlistCubit(repository);
    await cubit.load(1);

    await cubit.join(
      plate: 'ABC123',
      categoryId: 2,
      waitUntil: _waitUntil(),
      holdMinutes: 60,
      phone: '3001112233',
      name: 'Ana',
    );

    final ready = cubit.state as PublicWaitlistReady;
    expect(ready.entry?.id, 7);
    expect(cubit.phone, '3001112233');
    expect(repository.joins.single['phone'], '3001112233');
  });

  test('Failure: a throttled join keeps the failure and no entry', () async {
    final cubit = PublicWaitlistCubit(
      FakePublicWaitlistRepository()
        ..joinError = const ValidationFailure(
          'BookingThrottledError',
          'BookingThrottledError',
        ),
    );
    await cubit.load(1);

    await cubit.join(
      plate: 'ABC123',
      categoryId: 2,
      waitUntil: _waitUntil(),
      holdMinutes: 60,
      phone: '3001112233',
      name: 'Ana',
    );

    final ready = cubit.state as PublicWaitlistReady;
    expect(ready.entry, isNull);
    expect(ready.actionFailure?.code, 'BookingThrottledError');
  });

  test('Security: a refused captcha never stores an entry', () async {
    final cubit = PublicWaitlistCubit(
      FakePublicWaitlistRepository()
        ..joinError = const ValidationFailure(
          'CaptchaFailedError',
          'CaptchaFailedError',
        ),
    );
    await cubit.load(1);

    await cubit.join(
      plate: 'ABC123',
      categoryId: 2,
      waitUntil: _waitUntil(),
      holdMinutes: 60,
      phone: '3001112233',
      name: 'Ana',
      captchaToken: 'bad',
    );

    expect((cubit.state as PublicWaitlistReady).entry, isNull);
    expect(cubit.entryId, isNull);
  });

  test('Success: lookup then claim gives the hold', () async {
    final cubit = PublicWaitlistCubit(FakePublicWaitlistRepository());
    await cubit.load(1);

    await cubit.lookup(7, '3001112233');
    expect((cubit.state as PublicWaitlistReady).entry?.id, 7);

    await cubit.claim();

    final ready = cubit.state as PublicWaitlistReady;
    expect(ready.claimed, isNotNull);
    expect(ready.entry?.isClaimed, isTrue);
  });

  test('Failure: claiming a gone offer reports it', () async {
    final cubit = PublicWaitlistCubit(
      FakePublicWaitlistRepository()
        ..claimError = const ValidationFailure(
          'OfferNoLongerAvailableError',
          'OfferNoLongerAvailableError',
        ),
    );
    await cubit.load(1);
    await cubit.lookup(7, '3001112233');

    await cubit.claim();

    expect(
      (cubit.state as PublicWaitlistReady).actionFailure?.code,
      'OfferNoLongerAvailableError',
    );
  });

  test('Success: leaving marks the turn as left', () async {
    final cubit = PublicWaitlistCubit(FakePublicWaitlistRepository());
    await cubit.load(1);
    await cubit.lookup(7, '3001112233');

    await cubit.leave();

    expect((cubit.state as PublicWaitlistReady).entry?.status,
        WaitlistStatus.left);
  });

  test('Success: polling refreshes the turn', () async {
    final repository = FakePublicWaitlistRepository();
    final cubit = PublicWaitlistCubit(repository);
    await cubit.load(1);
    await cubit.lookup(7, '3001112233');
    final before = repository.lookups;

    repository.entry = PublicWaitlistEntry.fromJson({
      'id': 7,
      'plate': 'ABC123',
      'category_id': 2,
      'category_name': 'car',
      'status': 'offered',
      'position': 1,
      'wait_until': '2026-01-01T15:00:00Z',
      'hold_minutes': 60,
      'claim_minutes': 15,
      'offer_until': '2026-01-01T16:00:00Z',
      'reservation_id': 5,
      'notify_channel': 'screen',
    });
    await cubit.poll();

    expect(repository.lookups, before + 1);
    expect((cubit.state as PublicWaitlistReady).entry?.isOffered, isTrue);
  });

  test('Security: the poll timer stops when the cubit closes', () {
    fakeAsync((async) {
      final repository = FakePublicWaitlistRepository();
      final cubit = PublicWaitlistCubit(
        repository,
        pollInterval: const Duration(seconds: 30),
      );
      cubit.load(1);
      async.flushMicrotasks();
      cubit.lookup(7, '3001112233');
      async.flushMicrotasks();
      final before = repository.lookups;

      async.elapse(const Duration(seconds: 31));
      expect(repository.lookups, before + 1);

      cubit.close();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(repository.lookups, before + 1);
    });
  });
}
