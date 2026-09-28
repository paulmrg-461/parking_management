import 'dart:async';

import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';

/// In-memory `SyncOutbox` fake for repository/service tests. Exposes
/// [enqueued] so tests can assert exactly what was queued.
class FakeSyncOutbox implements SyncOutbox {
  final Map<int, PendingMutation> _entries = {};
  final List<PendingMutation> enqueued = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextKey = 0;

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    enqueued.add(mutation);
    _entries[_nextKey] = mutation;
    _nextKey++;
    _changes.add(null);
  }

  @override
  Future<List<OutboxEntry>> listPending() async =>
      _entries.entries.where((entry) => !entry.value.deadLettered).toList();

  @override
  Future<List<OutboxEntry>> listDeadLetters() async =>
      _entries.entries.where((entry) => entry.value.deadLettered).toList();

  @override
  Future<void> replace(int key, PendingMutation mutation) async {
    _entries[key] = mutation;
    _changes.add(null);
  }

  @override
  Future<void> remove(int key) async {
    _entries.remove(key);
    _changes.add(null);
  }

  @override
  Stream<void> watch() => _changes.stream;

  /// Whether anything is still subscribed to [watch].
  bool get hasWatchers => _changes.hasListener;

  /// Every entry (pending + dead letters), for assertions.
  List<PendingMutation> get all => _entries.values.toList();
}
