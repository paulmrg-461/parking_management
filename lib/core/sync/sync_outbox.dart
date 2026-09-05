import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import 'pending_mutation.dart';

/// Persists `update`/`delete` mutations that could not reach the backend
/// (network offline) so `SyncService` can replay them once connectivity is
/// restored.
abstract class SyncOutbox {
  Future<void> enqueue(PendingMutation mutation);

  /// Returns every pending mutation keyed by its storage key, so a caller
  /// can later target the exact entry to remove via [remove].
  Future<List<MapEntry<int, PendingMutation>>> listPending();

  Future<void> remove(int key);
}

/// JSON-in-a-`Box<String>` implementation: each entry's value is
/// `jsonEncode(mutation.toJson())`, keyed by an auto-incrementing int. This
/// avoids needing a Hive type adapter/typeId for a purely internal queue
/// record.
class HiveSyncOutbox implements SyncOutbox {
  static const _boxName = 'sync_outbox';

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    final box = await _box();
    await box.add(jsonEncode(mutation.toJson()));
  }

  @override
  Future<List<MapEntry<int, PendingMutation>>> listPending() async {
    final box = await _box();
    return box.keys.cast<int>().map((key) {
      final raw = box.get(key)!;
      final mutation = PendingMutation.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return MapEntry(key, mutation);
    }).toList();
  }

  @override
  Future<void> remove(int key) async {
    final box = await _box();
    await box.delete(key);
  }
}
