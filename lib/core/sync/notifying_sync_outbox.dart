import 'pending_mutation.dart';
import 'sync_outbox.dart';

/// [SyncOutbox] decorator that calls [_onEnqueued] after a mutation is
/// persisted, so `SyncService` drains right away instead of waiting for a
/// connectivity event (a write that failed on a flaky link while the device
/// still reports "online" would otherwise sit in the queue).
///
/// Only [enqueue] notifies: the drain's own `replace`/`remove` calls must not
/// re-trigger it.
class NotifyingSyncOutbox implements SyncOutbox {
  NotifyingSyncOutbox(this._inner, this._onEnqueued);

  final SyncOutbox _inner;
  final void Function() _onEnqueued;

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    await _inner.enqueue(mutation);
    try {
      _onEnqueued();
    } on Object {
      // The entry is safely queued; the next trigger drains it.
    }
  }

  @override
  Future<List<OutboxEntry>> listPending() => _inner.listPending();

  @override
  Future<List<OutboxEntry>> listDeadLetters() => _inner.listDeadLetters();

  @override
  Future<List<OutboxEntry>> listConflicts() => _inner.listConflicts();

  @override
  Future<void> settle(int key, PendingMutation expected) =>
      _inner.settle(key, expected);

  @override
  Future<void> replace(int key, PendingMutation mutation) =>
      _inner.replace(key, mutation);

  @override
  Future<void> remove(int key) => _inner.remove(key);

  @override
  Stream<void> watch() => _inner.watch();
}
