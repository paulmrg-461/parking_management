import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';

PendingMutation _mutation(int id) => PendingMutation(
  entityType: MutationEntity.vehicle,
  operation: MutationOperation.update,
  entityId: id,
  payloadJson: '{"color":"red"}',
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_outbox_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'Success: enqueue, listPending and remove round-trip a mutation',
    () async {
      final outbox = HiveSyncOutbox();

      await outbox.enqueue(_mutation(1));
      final pending = await outbox.listPending();

      expect(pending.single.value, _mutation(1));

      await outbox.remove(pending.single.key);

      expect(await outbox.listPending(), isEmpty);
    },
  );

  test(
    'Success: replace moves dead-lettered entries out of the pending list',
    () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(_mutation(1));
      await outbox.enqueue(_mutation(2));
      final first = (await outbox.listPending()).first;

      await outbox.replace(
        first.key,
        first.value.recordFailure('conflict', deadLettered: true),
      );

      expect((await outbox.listPending()).single.value.entityId, 2);
      final dead = await outbox.listDeadLetters();
      expect(dead.single.value.lastError, 'conflict');
    },
  );

  test('Success: watch emits on every change', () async {
    final outbox = HiveSyncOutbox();
    final events = <void>[];
    final subscription = outbox.watch().listen(events.add);
    await Future<void>.delayed(Duration.zero);

    await outbox.enqueue(_mutation(1));
    await Future<void>.delayed(Duration.zero);

    expect(events, isNotEmpty);
    await subscription.cancel();
  });

  test(
    'Security: a corrupt entry is skipped instead of breaking the queue',
    () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(_mutation(1));
      final box = await Hive.openBox<String>('sync_outbox');
      await box.add('{"entityType":"hacker","operation":"x"}');
      await box.add('not json');

      final pending = await outbox.listPending();

      expect(pending.single.value.entityId, 1);
    },
  );

  test(
    'Success: conflicts are listed apart from pending and dead letters',
    () async {
      final outbox = HiveSyncOutbox();
      final conflict = _mutation(2)
          .asConflict(kind: 'edited', serverRow: {'version': 9});
      await outbox.enqueue(_mutation(1));
      await outbox.enqueue(conflict);

      expect((await outbox.listPending()).map((e) => e.value.entityId), [1]);
      expect(await outbox.listDeadLetters(), isEmpty);
      final parked = await outbox.listConflicts();
      expect(parked.single.value.entityId, 2);
      expect(parked.single.value.conflictKind, 'edited');
    },
  );

  test('Success: settle removes only an unchanged entry', () async {
    final outbox = HiveSyncOutbox();
    await outbox.enqueue(_mutation(1));
    final entry = (await outbox.listPending()).single;

    // A coalesced edit written while the replay was in flight must survive.
    final coalesced = entry.value.withPayload('{"color":"green"}');
    await outbox.replace(entry.key, coalesced);
    await outbox.settle(entry.key, entry.value);
    expect((await outbox.listPending()).single.value, coalesced);

    await outbox.settle(entry.key, coalesced);
    expect(await outbox.listPending(), isEmpty);
  });
}
