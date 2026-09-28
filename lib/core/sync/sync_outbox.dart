import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import 'pending_mutation.dart';

typedef OutboxEntry = MapEntry<int, PendingMutation>;

/// Persists mutations that could not reach the backend so `SyncService` can
/// replay them later. Entries that keep failing are parked as dead letters
/// (see [PendingMutation.deadLettered]) for the operator to resolve.
abstract class SyncOutbox {
  Future<void> enqueue(PendingMutation mutation);

  /// Entries still eligible for replay, oldest first, keyed by storage key.
  Future<List<OutboxEntry>> listPending();

  /// Entries parked after exhausting retries or a non-retryable rejection.
  Future<List<OutboxEntry>> listDeadLetters();

  /// Overwrites the entry at [key] (retry metadata, dead-letter flag...).
  Future<void> replace(int key, PendingMutation mutation);

  Future<void> remove(int key);

  /// Emits whenever the queue changes (for badges / counters).
  Stream<void> watch();
}

/// JSON-in-a-`Box<String>` implementation keyed by auto-incrementing int.
/// The box is opened once and cached.
class HiveSyncOutbox implements SyncOutbox {
  static const _boxName = 'sync_outbox';

  Box<String>? _cached;

  Future<Box<String>> _box() async {
    final cached = _cached;
    if (cached != null && cached.isOpen) {
      return cached;
    }
    return _cached = await Hive.openBox<String>(_boxName);
  }

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    await (await _box()).add(jsonEncode(mutation.toJson()));
  }

  @override
  Future<List<OutboxEntry>> listPending() async =>
      (await _readAll()).where((e) => !e.value.deadLettered).toList();

  @override
  Future<List<OutboxEntry>> listDeadLetters() async =>
      (await _readAll()).where((e) => e.value.deadLettered).toList();

  @override
  Future<void> replace(int key, PendingMutation mutation) async {
    await (await _box()).put(key, jsonEncode(mutation.toJson()));
  }

  @override
  Future<void> remove(int key) async {
    await (await _box()).delete(key);
  }

  @override
  Stream<void> watch() async* {
    final box = await _box();
    yield* box.watch().map((_) {});
  }

  Future<List<OutboxEntry>> _readAll() async {
    final box = await _box();
    final entries = <OutboxEntry>[];
    for (final key in box.keys.cast<int>()) {
      final mutation = _decode(box.get(key));
      if (mutation != null) {
        entries.add(MapEntry(key, mutation));
      }
    }
    return entries;
  }

  /// Corrupt / unknown entries are skipped so they never block the queue.
  PendingMutation? _decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      return PendingMutation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
