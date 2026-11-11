import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../error/failure.dart';
import '../network/connectivity_service.dart';
import 'client_ref.dart';
import 'conflict/conflict_resolution.dart';
import 'conflict/three_way_merge.dart';
import 'mutation_replayer.dart';
import 'pending_mutation.dart';
import 'sync_outbox.dart';

/// Drains the [SyncOutbox] once connectivity is available.
///
/// Policy per entry:
/// - success → removed
/// - [ServerFailure] (5xx/429/timeout/transient SQL) → retried with
///   exponential backoff (2^n s, capped at [maxBackoff]); never dead-lettered
///   (the server is down, the mutation is fine)
/// - unknown [Failure] → same backoff, dead-lettered after [maxAttempts]
/// - [ValidationFailure] (409/422/403/…) or unexpected error → dead-lettered
///   at once (a 403 must never stall the rest of the queue)
/// - [NetworkFailure] → drain stops, entry untouched, and a retry timer is
///   armed ([stallBackoffFor]: 15s → 30s → 60s) because a flaky link may not
///   emit a connectivity event
/// - [AuthenticationFailure] → drain stops, entry untouched; the next login
///   or manual retry flushes again
///
/// A dead letter never blocks the queue: the loop continues with the next
/// entry. Concurrent [flush] calls share a single in-flight drain.
class SyncService {
  SyncService(
    this._outbox,
    this._connectivity,
    List<MutationReplayer> replayers, {
    DateTime Function()? clock,
  }) : _replayers = {for (final r in replayers) r.entity: r},
       _clock = clock ?? DateTime.now;

  static const maxAttempts = 5;

  /// Automatic merge rounds per entry; the next conflict is parked for the
  /// operator instead of looping.
  static const maxMergeRounds = 3;
  static const maxBackoff = Duration(minutes: 5);
  static const stallBase = Duration(seconds: 15);
  static const maxStallBackoff = Duration(seconds: 60);
  static const _idempotent = {MutationEntity.checkIn, MutationEntity.checkOut};

  final SyncOutbox _outbox;
  final ConnectivityService _connectivity;
  final Map<MutationEntity, MutationReplayer> _replayers;
  final DateTime Function() _clock;
  StreamSubscription<bool>? _subscription;
  Timer? _retryTimer;
  Future<void>? _inFlight;
  Duration? _retryDelay;
  final Map<int, int> _mergeRounds = {};
  int _stalls = 0;
  bool _stalled = false;

  /// Delay of the armed retry timer, `null` when none is armed.
  @visibleForTesting
  Duration? get nextRetryIn => _retryDelay;

  /// Flushes now and whenever the device comes back online.
  void start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        _kick();
      }
    });
    _kick();
  }

  /// Fire-and-forget flush right after a mutation is queued, so a write that
  /// failed on a flaky link is retried without waiting for an event.
  void onEnqueued() => _kick();

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryDelay = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> flush() =>
      _inFlight ??= _drain().whenComplete(() => _inFlight = null);

  /// Fire-and-forget flush (connectivity events, retry timer): errors are
  /// dropped here, entries stay queued for the next trigger.
  void _kick() => flush().ignore();

  /// Drops a dead letter after letting its replayer clean up side files.
  Future<void> discard(int key) async {
    for (final entry in await _outbox.listDeadLetters()) {
      if (entry.key == key) {
        await _replayers[entry.value.entityType]?.discard(entry.value);
        await _outbox.remove(key);
      }
    }
  }

  /// 2^[attempts] seconds, capped at [maxBackoff].
  static Duration backoffFor(int attempts) {
    final seconds = pow(2, attempts).toInt();
    return Duration(seconds: min(seconds, maxBackoff.inSeconds));
  }

  /// [stallBase] doubled per consecutive network stall, capped at
  /// [maxStallBackoff].
  static Duration stallBackoffFor(int stalls) {
    final seconds = stallBase.inSeconds * pow(2, min(stalls, 8)).toInt();
    return Duration(seconds: min(seconds, maxStallBackoff.inSeconds));
  }

  Future<void> _drain() async {
    if (!await _connectivity.isOnline()) {
      return;
    }
    _stalled = false;
    for (final entry in await _outbox.listPending()) {
      if (_isDue(entry.value) && !await _attempt(await _withKey(entry))) {
        break;
      }
    }
    await _scheduleRetry();
  }

  bool _isDue(PendingMutation mutation) {
    final next = mutation.nextAttemptAt;
    return next == null || !next.isAfter(_clock());
  }

  /// Returns `false` when the whole drain must stop.
  Future<bool> _attempt(OutboxEntry entry) async {
    try {
      await _replay(entry.value);
      // Settle, not remove: an edit coalesced while the replay was in flight
      // must survive.
      await _outbox.settle(entry.key, entry.value);
      _mergeRounds.remove(entry.key);
      return true;
    } on Failure catch (failure) {
      return _onFailure(entry, failure);
    } catch (error) {
      await _park(entry, 'Unexpected error: ${error.runtimeType}');
      return true;
    }
  }

  Future<int?> _replay(PendingMutation mutation) {
    final replayer = _replayers[mutation.entityType];
    if (replayer == null) {
      throw StateError('No replayer for ${mutation.entityType.name}');
    }
    return replayer.replay(mutation);
  }

  Future<bool> _onFailure(OutboxEntry entry, Failure failure) async {
    switch (failure) {
      case ServerFailure():
        await _backOff(entry, failure.message);
      case NetworkFailure():
        _stalled = true;
        return false;
      case AuthenticationFailure():
        return false;
      case VersionConflictFailure():
        return _onConflict(entry, failure);
      case ValidationFailure():
        await _park(entry, failure.message);
      default:
        await _retryLater(entry, failure.message);
    }
    return true;
  }

  Future<bool> _onConflict(
    OutboxEntry entry,
    VersionConflictFailure failure,
  ) async {
    final mutation = entry.value;
    final server = failure.serverRow;

    if (mutation.operation == MutationOperation.delete) {
      if (server == null) {
        // Already gone: the intent holds.
        await _outbox.settle(entry.key, mutation);
        return true;
      }
      return _parkConflict(entry, 'edited', server);
    }

    if (server == null) {
      return _parkConflict(entry, 'deleted', null);
    }

    final plan = planMerge(
      base: mutation.decodeBaseSnapshot(),
      mine: mutation.decodePayload(),
      theirs: server,
    );
    if (plan.serverAlreadyHasMine) {
      await _adopt(mutation, server);
      await _outbox.settle(entry.key, mutation);
      return true;
    }

    final rounds = _mergeRounds[entry.key] ?? 0;
    if (plan.conflicts.isEmpty && plan.autoApply.isNotEmpty) {
      if (rounds < maxMergeRounds) {
        _mergeRounds[entry.key] = rounds + 1;
        await _outbox.replace(
          entry.key,
          mutation.rebased(
            baseVersion: (server['version'] as num?)?.toInt() ?? 0,
            payloadJson: jsonEncode(plan.autoApply),
            baseSnapshotJson: jsonEncode(server),
          ),
        );
        return true;
      }
    }
    return _parkConflict(entry, 'edited', server);
  }

  Future<bool> _parkConflict(
    OutboxEntry entry,
    String kind,
    Map<String, dynamic>? server,
  ) async {
    await _outbox.replace(
      entry.key,
      entry.value.asConflict(kind: kind, serverRow: server),
    );
    return true;
  }

  Future<void> _adopt(
    PendingMutation mutation,
    Map<String, dynamic>? row,
  ) async {
    final replayer = _replayers[mutation.entityType];
    try {
      await replayer?.adoptServer(row);
    } on Object {
      // The queue is already in a good state; a cache refresh is best effort.
    }
  }

  /// Resolves a parked conflict: keep the server's row or re-send mine on top
  /// of it. `keepMine` leaves the entry pending so the next drain replays it.
  Future<void> resolve(int key, ConflictChoice choice) async {
    final entries = await _outbox.listConflicts();
    final entry = entries
        .where((candidate) => candidate.key == key)
        .firstOrNull;
    if (entry == null) {
      return;
    }
    final mutation = entry.value;
    final server = mutation.decodeServerRow();
    _mergeRounds.remove(key);
    if (choice == ConflictChoice.keepTheirs || server == null) {
      await _adopt(mutation, server);
      await _outbox.remove(key);
      return;
    }
    await _outbox.replace(
      key,
      mutation.rebased(
        baseVersion: (server['version'] as num?)?.toInt() ?? 0,
        payloadJson: jsonEncode(mutation.decodePayload()),
        baseSnapshotJson: jsonEncode(server),
      ),
    );
    _kick();
  }

  Future<void> _retryLater(OutboxEntry entry, String message) async {
    if (entry.value.attempts + 1 >= maxAttempts) {
      return _park(entry, message);
    }
    await _backOff(entry, message);
  }

  Future<void> _backOff(OutboxEntry entry, String message) async {
    final next = _clock().add(backoffFor(entry.value.attempts + 1));
    await _outbox.replace(
      entry.key,
      entry.value.recordFailure(message, nextAttemptAt: next),
    );
  }

  Future<void> _park(OutboxEntry entry, String message) => _outbox.replace(
    entry.key,
    entry.value.recordFailure(message, deadLettered: true),
  );

  /// Legacy check-in/check-out entries may lack a `client_ref`; one is
  /// generated and persisted BEFORE the first replay so every retry sends
  /// the same `Idempotency-Key`.
  Future<OutboxEntry> _withKey(OutboxEntry entry) async {
    final mutation = entry.value;
    final payload = mutation.decodePayload();
    if (!_idempotent.contains(mutation.entityType) ||
        payload['client_ref'] is String) {
      return entry;
    }
    payload['client_ref'] = newClientRef();
    final keyed = mutation.withPayload(jsonEncode(payload));
    await _outbox.replace(entry.key, keyed);
    return MapEntry(entry.key, keyed);
  }

  Future<void> _scheduleRetry() async {
    _retryTimer?.cancel();
    final delay = _shorter(_stallDelay(), await _dueDelay());
    _retryDelay = delay;
    if (delay != null) {
      _retryTimer = Timer(delay, _kick);
    }
  }

  /// Consecutive network stalls grow the delay; a clean drain resets it.
  Duration? _stallDelay() {
    if (!_stalled) {
      _stalls = 0;
      return null;
    }
    return stallBackoffFor(_stalls++);
  }

  Future<Duration?> _dueDelay() async {
    final due = (await _outbox.listPending())
        .map((entry) => entry.value.nextAttemptAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    return due?.difference(_clock());
  }

  static Duration? _shorter(Duration? a, Duration? b) {
    if (a == null || b == null) {
      return a ?? b;
    }
    return a < b ? a : b;
  }
}
