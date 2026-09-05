import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';

/// In-memory `SyncOutbox` fake for repository/service tests. Exposes
/// [enqueued] so tests can assert exactly what was queued.
class FakeSyncOutbox implements SyncOutbox {
  final Map<int, PendingMutation> _entries = {};
  final List<PendingMutation> enqueued = [];
  int _nextKey = 0;

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    enqueued.add(mutation);
    _entries[_nextKey] = mutation;
    _nextKey++;
  }

  @override
  Future<List<MapEntry<int, PendingMutation>>> listPending() async =>
      _entries.entries.toList();

  @override
  Future<void> remove(int key) async {
    _entries.remove(key);
  }
}
