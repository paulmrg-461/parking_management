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
}
