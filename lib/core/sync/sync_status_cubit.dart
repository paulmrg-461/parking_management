import 'dart:async';

import 'package:equatable/equatable.dart';

import 'conflict/conflict_resolution.dart';
import 'sync_outbox.dart';
import '../state/resilient_cubit.dart';

typedef DeadLetterDiscarder = Future<void> Function(int key);
typedef ConflictResolver = Future<void> Function(
  int key,
  ConflictResolution resolution,
);

class SyncStatus extends Equatable {
  const SyncStatus({
    this.pendingCount = 0,
    this.deadLetters = const [],
    this.conflicts = const [],
  });

  final int pendingCount;
  final List<OutboxEntry> deadLetters;

  /// Entries parked for the operator after a version conflict.
  final List<OutboxEntry> conflicts;

  bool get hasWork =>
      pendingCount > 0 || deadLetters.isNotEmpty || conflicts.isNotEmpty;

  int get total => pendingCount + deadLetters.length + conflicts.length;

  @override
  List<Object?> get props => [pendingCount, deadLetters, conflicts];
}

/// Exposes the outbox size (pending + dead letters) for the `SyncBadge`
/// and lets the operator discard a dead letter.
class SyncStatusCubit extends ResilientCubit<SyncStatus> {
  SyncStatusCubit(this._outbox, this._discard, [this._flush, this._resolve])
    : super(const SyncStatus()) {
    _subscription = _outbox.watch().listen((_) => load());
  }

  final SyncOutbox _outbox;
  final DeadLetterDiscarder _discard;
  final Future<void> Function()? _flush;
  final ConflictResolver? _resolve;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    final pending = await _outbox.listPending();
    final dead = await _outbox.listDeadLetters();
    final conflicts = await _outbox.listConflicts();
    if (!isClosed) {
      emit(
        SyncStatus(
          pendingCount: pending.length,
          deadLetters: dead,
          conflicts: conflicts,
        ),
      );
    }
  }

  /// Applies the operator's choice to a parked conflict and reloads.
  Future<void> resolve(int key, ConflictResolution resolution) async {
    await _resolve?.call(key, resolution);
    await load();
  }

  Future<void> discard(int key) async {
    await _discard(key);
    await load();
  }

  /// Manual "retry now" for a queue that is waiting on a backoff timer or a
  /// login that already happened.
  Future<void> syncNow() async {
    await _flush?.call();
    await load();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
