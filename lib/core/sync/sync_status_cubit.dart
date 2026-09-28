import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_outbox.dart';

typedef DeadLetterDiscarder = Future<void> Function(int key);

class SyncStatus extends Equatable {
  const SyncStatus({this.pendingCount = 0, this.deadLetters = const []});

  final int pendingCount;
  final List<OutboxEntry> deadLetters;

  bool get hasWork => pendingCount > 0 || deadLetters.isNotEmpty;

  int get total => pendingCount + deadLetters.length;

  @override
  List<Object?> get props => [pendingCount, deadLetters];
}

/// Exposes the outbox size (pending + dead letters) for the `SyncBadge`
/// and lets the operator discard a dead letter.
class SyncStatusCubit extends Cubit<SyncStatus> {
  SyncStatusCubit(this._outbox, this._discard) : super(const SyncStatus()) {
    _subscription = _outbox.watch().listen((_) => load());
  }

  final SyncOutbox _outbox;
  final DeadLetterDiscarder _discard;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    final pending = await _outbox.listPending();
    final dead = await _outbox.listDeadLetters();
    if (!isClosed) {
      emit(SyncStatus(pendingCount: pending.length, deadLetters: dead));
    }
  }

  Future<void> discard(int key) async {
    await _discard(key);
    await load();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
