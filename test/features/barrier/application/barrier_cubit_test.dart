import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/barrier/application/barrier_cubit.dart';
import 'package:parking_management/features/barrier/domain/commands/barrier_config_update.dart';
import 'package:parking_management/features/barrier/domain/commands/open_barrier_request.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier_command.dart';

import '../../../helpers/fake_barrier_repository.dart';

void main() {
  test('load emits the barriers', () async {
    final cubit = BarrierCubit(FakeBarrierRepository());
    await cubit.load();
    final state = cubit.state as BarrierLoaded;
    expect(state.barriers.single.name, 'Salida');
    await cubit.close();
  });

  test('no barriers emits the empty state', () async {
    final cubit = BarrierCubit(FakeBarrierRepository()..barriers = []);
    await cubit.load();
    expect(cubit.state, isA<BarrierEmpty>());
    await cubit.close();
  });

  test('a load failure keeps the retry path', () async {
    final cubit = BarrierCubit(
      FakeBarrierRepository()..listError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<BarrierFailure>());
    await cubit.close();
  });

  test('a manual open tracks the command until it is executed', () {
    fakeAsync((async) {
      final repository = FakeBarrierRepository()
        ..pollStatuses = const [
          BarrierCommandStatus.delivered,
          BarrierCommandStatus.executed,
        ];
      final cubit = BarrierCubit(repository);
      cubit.load();
      async.flushMicrotasks();
      cubit.openManually(
        const OpenBarrierRequest(deviceId: 1, reason: 'Cliente sin ticket'),
      );
      async.flushMicrotasks();
      var state = cubit.state as BarrierLoaded;
      expect(state.tracking?.status, BarrierCommandStatus.queued);
      expect(repository.opened.single.reason, 'Cliente sin ticket');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      state = cubit.state as BarrierLoaded;
      expect(state.tracking?.status, BarrierCommandStatus.delivered);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      state = cubit.state as BarrierLoaded;
      expect(state.tracking?.status, BarrierCommandStatus.executed);
      expect(cubit.isTracking, isFalse);
      cubit.close();
    });
  });

  test('an open failure keeps the list and reports it', () async {
    final cubit = BarrierCubit(
      FakeBarrierRepository()..openError = const ValidationFailure('bad'),
    );
    await cubit.load();
    await cubit.openManually(
      const OpenBarrierRequest(deviceId: 1, reason: 'Cliente sin ticket'),
    );
    final state = cubit.state as BarrierLoaded;
    expect(state.submission, isA<SubmissionFailed>());
    expect(cubit.isTracking, isFalse);
    await cubit.close();
  });

  test('saving the config calls the repository and refreshes', () async {
    final repository = FakeBarrierRepository();
    final cubit = BarrierCubit(repository);
    await cubit.load();
    await cubit.saveConfig(const BarrierConfigUpdate(
      deviceId: 1,
      openOnCheckin: 'always',
    ));
    expect(repository.saved.single.openOnCheckin, 'always');
    expect((cubit.state as BarrierLoaded).submission, isA<SubmissionSucceeded>());
    await cubit.close();
  });

  test('a poll failure stops the tracking and reports it', () {
    fakeAsync((async) {
      final repository = FakeBarrierRepository()
        ..pollStatuses = const [BarrierCommandStatus.delivered];
      final cubit = BarrierCubit(repository);
      cubit.load();
      async.flushMicrotasks();
      cubit.openManually(
        const OpenBarrierRequest(deviceId: 1, reason: 'Cliente sin ticket'),
      );
      async.flushMicrotasks();
      repository.commandError = const NetworkFailure('offline');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      final state = cubit.state as BarrierLoaded;
      expect(state.submission, isA<SubmissionFailed>());
      expect(cubit.isTracking, isFalse);
      cubit.close();
    });
  });

  test('tracking stops after the maximum number of polls', () {
    fakeAsync((async) {
      final repository = FakeBarrierRepository()
        ..pollStatuses = const [BarrierCommandStatus.delivered];
      final cubit = BarrierCubit(repository);
      cubit.load();
      async.flushMicrotasks();
      cubit.openManually(
        const OpenBarrierRequest(deviceId: 1, reason: 'Cliente sin ticket'),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 41));
      async.flushMicrotasks();
      expect(cubit.isTracking, isFalse);
      expect(repository.commandCalls, BarrierCubit.maxPolls);
      cubit.close();
    });
  });

  test('a save failure keeps the list and reports it', () async {
    final cubit = BarrierCubit(
      FakeBarrierRepository()..saveError = const ValidationFailure('bad'),
    );
    await cubit.load();
    await cubit.saveConfig(const BarrierConfigUpdate(
      deviceId: 1,
      openOnCheckin: 'always',
    ));
    expect((cubit.state as BarrierLoaded).submission, isA<SubmissionFailed>());
    await cubit.close();
  });

  test('closing stops the tracking timer', () {
    fakeAsync((async) {
      final repository = FakeBarrierRepository()
        ..pollStatuses = const [BarrierCommandStatus.queued];
      final cubit = BarrierCubit(repository);
      cubit.load();
      async.flushMicrotasks();
      cubit.openManually(
        const OpenBarrierRequest(deviceId: 1, reason: 'Cliente sin ticket'),
      );
      async.flushMicrotasks();
      cubit.close();
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(repository.commandCalls, 0);
    });
  });
}
