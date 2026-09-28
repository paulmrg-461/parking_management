import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/sync/mutation_replayer.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_service.dart';

import '../../helpers/fake_sync_outbox.dart';

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.online = true});

  bool online;
  final StreamController<bool> changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onConnectivityChanged => changes.stream;
}

/// Scriptable replayer: pops one outcome per call (null = success).
class _FakeReplayer extends MutationReplayer {
  _FakeReplayer(this.entity, [List<Object?> outcomes = const []])
    : _outcomes = List.of(outcomes);

  @override
  final MutationEntity entity;
  final List<Object?> _outcomes;
  final List<PendingMutation> replayed = [];
  final List<PendingMutation> discarded = [];
  Completer<void>? gate;

  @override
  Future<void> replay(PendingMutation mutation) async {
    replayed.add(mutation);
    await gate?.future;
    final outcome = _outcomes.isEmpty ? null : _outcomes.removeAt(0);
    if (outcome != null) {
      throw outcome;
    }
  }

  @override
  Future<void> discard(PendingMutation mutation) async =>
      discarded.add(mutation);
}

PendingMutation _vehicleUpdate(int id) => PendingMutation(
  entityType: MutationEntity.vehicle,
  operation: MutationOperation.update,
  entityId: id,
  payloadJson: '{"color":"red"}',
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

PendingMutation _checkOut({
  String payload = '{"client_exit_time":"2026-01-01T10:00:00.000"}',
}) => PendingMutation(
  entityType: MutationEntity.checkOut,
  operation: MutationOperation.close,
  entityId: 5,
  payloadJson: payload,
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

class _Harness {
  _Harness({List<MutationReplayer> replayers = const [], bool online = true})
    : connectivity = _FakeConnectivity(online: online) {
    service = SyncService(outbox, connectivity, replayers, clock: () => now);
  }

  final FakeSyncOutbox outbox = FakeSyncOutbox();
  final _FakeConnectivity connectivity;
  late final SyncService service;
  DateTime now = DateTime.utc(2026, 1, 1, 12);
}

void main() {
  group('SyncService.flush', () {
    test('Success: replays a pending entry and removes it', () async {
      final vehicles = _FakeReplayer(MutationEntity.vehicle);
      final h = _Harness(replayers: [vehicles]);
      await h.outbox.enqueue(_vehicleUpdate(1));

      await h.service.flush();

      expect(vehicles.replayed.single.entityId, 1);
      expect(h.outbox.all, isEmpty);
    });

    test(
      'Success: concurrent flush calls share one drain (1 replay)',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle)
          ..gate = Completer<void>();
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));

        final first = h.service.flush();
        final second = h.service.flush();
        await Future<void>.delayed(Duration.zero);
        vehicles.gate!.complete();
        await Future.wait([first, second]);

        expect(vehicles.replayed, hasLength(1));
        expect(h.outbox.all, isEmpty);
      },
    );

    test('Success: does nothing when offline', () async {
      final vehicles = _FakeReplayer(MutationEntity.vehicle);
      final h = _Harness(replayers: [vehicles], online: false);
      await h.outbox.enqueue(_vehicleUpdate(1));

      await h.service.flush();

      expect(vehicles.replayed, isEmpty);
      expect(h.outbox.all, hasLength(1));
    });

    test(
      'Failure: NetworkFailure stops the drain and keeps entries untouched',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle, [
          const NetworkFailure('offline'),
        ]);
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));
        await h.outbox.enqueue(_vehicleUpdate(2));

        await expectLater(h.service.flush(), completes);

        expect(vehicles.replayed, hasLength(1));
        expect(h.outbox.all, [_vehicleUpdate(1), _vehicleUpdate(2)]);
      },
    );

    test(
      'Failure: 409 dead-letters immediately and the queue continues',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle, [
          const ValidationFailure('Conflict'),
        ]);
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));
        await h.outbox.enqueue(_vehicleUpdate(2));

        await h.service.flush();

        expect(vehicles.replayed.map((m) => m.entityId), [1, 2]);
        final dead = await h.outbox.listDeadLetters();
        expect(dead.single.value.entityId, 1);
        expect(dead.single.value.lastError, 'Conflict');
        expect(dead.single.value.attempts, 1);
        expect(await h.outbox.listPending(), isEmpty);
      },
    );

    test(
      'Failure: 5xx backs off 2^n s, skips until due, then retries',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle, [
          const ServerFailure(),
        ]);
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));

        await h.service.flush();
        final retry = (await h.outbox.listPending()).single.value;
        expect(retry.attempts, 1);
        expect(retry.nextAttemptAt, h.now.add(const Duration(seconds: 2)));

        h.now = h.now.add(const Duration(seconds: 1));
        await h.service.flush();
        expect(vehicles.replayed, hasLength(1));

        h.now = h.now.add(const Duration(seconds: 1));
        await h.service.flush();
        expect(vehicles.replayed, hasLength(2));
        expect(h.outbox.all, isEmpty);
        await h.service.dispose();
      },
    );

    test('Failure: dead-letters after 5 retryable failures', () async {
      final vehicles = _FakeReplayer(
        MutationEntity.vehicle,
        List.filled(5, const ServerFailure()),
      );
      final h = _Harness(replayers: [vehicles]);
      await h.outbox.enqueue(_vehicleUpdate(1));

      for (var i = 0; i < 5; i++) {
        await h.service.flush();
        h.now = h.now.add(SyncService.maxBackoff);
      }

      expect(vehicles.replayed, hasLength(5));
      final dead = (await h.outbox.listDeadLetters()).single.value;
      expect(dead.attempts, 5);
      await h.service.dispose();
    });

    test(
      'Failure: AuthenticationFailure stops the drain without burning attempts',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle, [
          const AuthenticationFailure('Invalid credentials'),
        ]);
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));

        await h.service.flush();

        expect((await h.outbox.listPending()).single.value.attempts, 0);
      },
    );

    test('Security: a poison entry (unexpected error) is parked, not retried forever', () async {
      final vehicles = _FakeReplayer(MutationEntity.vehicle, [
        const FormatException('bad payload'),
      ]);
      final h = _Harness(replayers: [vehicles]);
      await h.outbox.enqueue(_vehicleUpdate(1));
      await h.outbox.enqueue(_vehicleUpdate(2));

      await h.service.flush();

      expect((await h.outbox.listDeadLetters()).single.value.entityId, 1);
      expect(vehicles.replayed, hasLength(2));
    });

    test('Security: legacy check-out without client_ref gets one persisted, reused on retry', () async {
      final checkOuts = _FakeReplayer(MutationEntity.checkOut, [
        const ServerFailure(),
      ]);
      final h = _Harness(replayers: [checkOuts]);
      await h.outbox.enqueue(_checkOut());

      await h.service.flush();
      h.now = h.now.add(SyncService.maxBackoff);
      await h.service.flush();

      final keys = checkOuts.replayed
          .map((m) => m.decodePayload()['client_ref'] as String?)
          .toList();
      expect(keys, hasLength(2));
      expect(keys.first, isNotEmpty);
      expect(keys.first, keys.last);
      await h.service.dispose();
    });
  });

  group('SyncService lifecycle & dead letters', () {
    test(
      'Success: discard removes a dead letter and lets the replayer clean up',
      () async {
        final vehicles = _FakeReplayer(MutationEntity.vehicle, [
          const ValidationFailure('Not found'),
        ]);
        final h = _Harness(replayers: [vehicles]);
        await h.outbox.enqueue(_vehicleUpdate(1));
        await h.service.flush();
        final key = (await h.outbox.listDeadLetters()).single.key;

        await h.service.discard(key);

        expect(h.outbox.all, isEmpty);
        expect(vehicles.discarded.single.entityId, 1);
      },
    );

    test('Success: coming back online triggers a flush', () async {
      final vehicles = _FakeReplayer(MutationEntity.vehicle);
      final h = _Harness(replayers: [vehicles], online: false);
      await h.outbox.enqueue(_vehicleUpdate(1));
      h.service.start();
      await Future<void>.delayed(Duration.zero);

      h.connectivity.online = true;
      h.connectivity.changes.add(true);
      await Future<void>.delayed(Duration.zero);
      await h.service.flush();

      expect(vehicles.replayed, hasLength(1));
      await h.service.dispose();
    });

    test('Security: dispose cancels the connectivity subscription', () async {
      final h = _Harness(online: false);
      h.service.start();
      expect(h.connectivity.changes.hasListener, isTrue);

      await h.service.dispose();

      expect(h.connectivity.changes.hasListener, isFalse);
    });
  });
}
