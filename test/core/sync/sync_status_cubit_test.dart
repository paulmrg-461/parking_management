import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_status_cubit.dart';

import '../../helpers/fake_sync_outbox.dart';

PendingMutation _mutation({bool dead = false}) => PendingMutation(
  entityType: MutationEntity.checkOut,
  operation: MutationOperation.close,
  entityId: 5,
  payloadJson: '{}',
  enqueuedAt: DateTime.utc(2026, 1, 1),
  lastError: dead ? 'Session already closed' : null,
  deadLettered: dead,
);

void main() {
  test(
    'Success: reports pending count and dead letters, refreshing on changes',
    () async {
      final outbox = FakeSyncOutbox();
      await outbox.enqueue(_mutation(dead: true));
      final cubit = SyncStatusCubit(outbox, outbox.remove);
      await cubit.load();
      expect(cubit.state.pendingCount, 0);
      expect(
        cubit.state.deadLetters.single.value.lastError,
        'Session already closed',
      );

      await outbox.enqueue(_mutation());
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.pendingCount, 1);
      expect(cubit.state.hasWork, isTrue);
      await cubit.close();
    },
  );

  test('Failure: discard delegates to the discarder and reloads', () async {
    final outbox = FakeSyncOutbox();
    await outbox.enqueue(_mutation(dead: true));
    final discarded = <int>[];
    final cubit = SyncStatusCubit(outbox, (key) async {
      discarded.add(key);
      await outbox.remove(key);
    });
    await cubit.load();

    await cubit.discard(cubit.state.deadLetters.single.key);

    expect(discarded, [0]);
    expect(cubit.state.deadLetters, isEmpty);
    expect(cubit.state.hasWork, isFalse);
    await cubit.close();
  });

  test('Security: close cancels the outbox subscription', () async {
    final outbox = FakeSyncOutbox();
    final cubit = SyncStatusCubit(outbox, outbox.remove);
    expect(outbox.hasWatchers, isTrue);

    await cubit.close();

    expect(outbox.hasWatchers, isFalse);
  });
}
