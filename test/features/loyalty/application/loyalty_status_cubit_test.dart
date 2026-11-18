import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/loyalty/application/loyalty_status_cubit.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_status.dart';

import '../../../helpers/fake_loyalty_repository.dart';

class _DelayedRepository extends FakeLoyaltyRepository {
  final answers = <String, Completer<LoyaltyStatus>>{};

  @override
  Future<LoyaltyStatus> status(String plate) {
    final completer = Completer<LoyaltyStatus>();
    answers[plate] = completer;
    return completer.future;
  }
}

void main() {
  test('Success: load emits loading then ready', () async {
    final cubit = LoyaltyStatusCubit(FakeLoyaltyRepository());
    final states = <LoyaltyStatusState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load('abc123');

    expect(states.first, isA<LoyaltyStatusLoading>());
    expect(cubit.state, isA<LoyaltyStatusReady>());
    expect((cubit.state as LoyaltyStatusReady).status.visits, 3);
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: a short plate is ignored', () async {
    final repository = FakeLoyaltyRepository();
    final cubit = LoyaltyStatusCubit(repository);

    await cubit.load('ab');

    expect(cubit.state, isA<LoyaltyStatusIdle>());
    expect(repository.statusCalls, 0);
    await cubit.close();
  });

  test('Failure: a network error emits idle (offline hides the chip)', () async {
    final cubit = LoyaltyStatusCubit(
      FakeLoyaltyRepository()
        ..statusError = const NetworkFailure('offline'),
    );
    await cubit.load('ABC123');
    expect(cubit.state, isA<LoyaltyStatusIdle>());
    await cubit.close();
  });

  test('Success: a disabled program emits idle', () async {
    final cubit = LoyaltyStatusCubit(
      FakeLoyaltyRepository(
        statusResult: const LoyaltyStatus(enabled: false),
      ),
    );
    await cubit.load('ABC123');
    expect(cubit.state, isA<LoyaltyStatusIdle>());
    await cubit.close();
  });

  test('Failure: a server error emits a retryable failure', () async {
    final repository = FakeLoyaltyRepository()
      ..statusError = const ValidationFailure(
        'InvalidPlateError',
        'InvalidPlateError',
      );
    final cubit = LoyaltyStatusCubit(repository);
    await cubit.load('ABC123');
    expect(cubit.state, isA<LoyaltyStatusFailure>());

    repository.statusError = null;
    await cubit.retry();
    expect(cubit.state, isA<LoyaltyStatusReady>());
    await cubit.close();
  });

  test('Security: a stale answer is dropped when the plate changed', () async {
    final repository = _DelayedRepository();
    final cubit = LoyaltyStatusCubit(repository);

    final first = cubit.load('AAA111');
    final second = cubit.load('BBB222');
    repository.answers['BBB222']!.complete(
      const LoyaltyStatus(enabled: true, plate: 'BBB222', visits: 1),
    );
    await second;
    repository.answers['AAA111']!.complete(
      const LoyaltyStatus(enabled: true, plate: 'AAA111', visits: 4),
    );
    await first;

    expect(cubit.state, isA<LoyaltyStatusReady>());
    expect((cubit.state as LoyaltyStatusReady).status.plate, 'BBB222');
    await cubit.close();
  });

  test('Success: clear emits idle', () async {
    final cubit = LoyaltyStatusCubit(FakeLoyaltyRepository());
    await cubit.load('ABC123');
    cubit.clear();
    expect(cubit.state, isA<LoyaltyStatusIdle>());
    await cubit.close();
  });
}
