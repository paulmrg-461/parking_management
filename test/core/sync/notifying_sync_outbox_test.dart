import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/notifying_sync_outbox.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';

import '../../helpers/fake_sync_outbox.dart';

PendingMutation _mutation() => PendingMutation(
  entityType: MutationEntity.checkOut,
  operation: MutationOperation.close,
  entityId: 5,
  payloadJson: '{"client_ref":"ref"}',
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  test('Success: enqueue persists first, then notifies once', () async {
    final inner = FakeSyncOutbox();
    var notified = 0;
    var persistedWhenNotified = false;
    final outbox = NotifyingSyncOutbox(inner, () {
      notified++;
      persistedWhenNotified = inner.enqueued.isNotEmpty;
    });

    await outbox.enqueue(_mutation());

    expect(notified, 1);
    expect(persistedWhenNotified, isTrue);
    expect(await outbox.listPending(), hasLength(1));
  });

  test('Failure: replace/remove (drain bookkeeping) never notifies', () async {
    final inner = FakeSyncOutbox();
    var notified = 0;
    final outbox = NotifyingSyncOutbox(inner, () => notified++);
    await inner.enqueue(_mutation());
    final key = (await outbox.listPending()).single.key;

    await outbox.replace(key, _mutation().recordFailure('x'));
    await outbox.remove(key);

    expect(notified, 0);
    expect(inner.all, isEmpty);
  });

  test('Security: a throwing listener never loses the queued entry', () async {
    final inner = FakeSyncOutbox();
    final outbox = NotifyingSyncOutbox(inner, () => throw StateError('boom'));

    await outbox.enqueue(_mutation());

    expect(inner.enqueued, hasLength(1));
  });
}
