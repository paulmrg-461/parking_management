import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';

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

  test('enqueue, listPending and remove round-trip a pending mutation', () async {
    final outbox = HiveSyncOutbox();
    final mutation = PendingMutation(
      entityType: 'vehicle',
      operation: 'update',
      entityId: 1,
      payloadJson: '{"color":"red"}',
      enqueuedAt: DateTime.utc(2026, 1, 1),
    );

    await outbox.enqueue(mutation);
    final pending = await outbox.listPending();

    expect(pending, hasLength(1));
    expect(pending.single.value.entityType, 'vehicle');
    expect(pending.single.value.operation, 'update');
    expect(pending.single.value.entityId, 1);
    expect(pending.single.value.payloadJson, '{"color":"red"}');

    await outbox.remove(pending.single.key);

    expect(await outbox.listPending(), isEmpty);
  });

  test('listPending returns multiple entries independently', () async {
    final outbox = HiveSyncOutbox();
    await outbox.enqueue(
      PendingMutation(
        entityType: 'tariff',
        operation: 'delete',
        entityId: 5,
        payloadJson: null,
        enqueuedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await outbox.enqueue(
      PendingMutation(
        entityType: 'category',
        operation: 'update',
        entityId: 7,
        payloadJson: '{"name":"bus"}',
        enqueuedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final pending = await outbox.listPending();

    expect(pending, hasLength(2));
    expect(pending.map((e) => e.value.entityId), containsAll([5, 7]));
  });
}
