import 'package:equatable/equatable.dart';

import '../../error/failure.dart';
import '../../state/resilient_cubit.dart';
import '../pending_mutation.dart';
import '../sync_outbox.dart';
import 'conflict_resolution.dart';
import 'three_way_merge.dart';

/// Which of the three conflict shapes the entry has.
enum ConflictKind {
  /// Both sides edited at least one field.
  edited,

  /// My edit met a row someone else deleted.
  deleted,

  /// My delete met a row someone else edited.
  deletedElsewhere,
}

/// The three-way merge of a parked entry: what merges cleanly and what only a
/// human can decide.
MergePlan planFor(OutboxEntry entry) => planMerge(
  base: entry.value.decodeBaseSnapshot(),
  mine: entry.value.decodePayload(),
  theirs: entry.value.decodeServerRow() ?? const {},
);

ConflictKind kindOf(PendingMutation mutation) {
  if (mutation.conflictKind == 'deleted') {
    return ConflictKind.deleted;
  }
  if (mutation.operation == MutationOperation.delete) {
    return ConflictKind.deletedElsewhere;
  }
  return ConflictKind.edited;
}

sealed class ConflictResolutionState extends Equatable {
  const ConflictResolutionState({required this.entry});

  final OutboxEntry entry;

  @override
  List<Object?> get props => [entry.key, entry.value];
}

/// Waiting for the operator, with the per-field choices made so far.
final class ConflictResolutionIdle extends ConflictResolutionState {
  const ConflictResolutionIdle({
    required super.entry,
    required this.plan,
    this.choices = const {},
    this.conflictAgain = false,
  });

  final MergePlan plan;

  /// Every field the operator already decided, `true` = mine, `false` = theirs.
  final Map<String, bool> choices;

  /// The server row changed since the dialog was last shown.
  final bool conflictAgain;

  bool get complete =>
      plan.conflicts.every((conflict) => choices.containsKey(conflict.field));

  /// The fields where "mine" wins.
  Set<String> get mineFields => {
    for (final entry in choices.entries)
      if (entry.value) entry.key,
  };

  @override
  List<Object?> get props => [...super.props, plan, choices, conflictAgain];
}

final class ConflictResolutionSubmitting extends ConflictResolutionState {
  const ConflictResolutionSubmitting({required super.entry});
}

/// The choice was applied; the dialog closes.
final class ConflictResolutionDone extends ConflictResolutionState {
  const ConflictResolutionDone({required super.entry});
}

final class ConflictResolutionFailed extends ConflictResolutionState {
  const ConflictResolutionFailed({required super.entry, required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [...super.props, failure.message, failure.code];
}

typedef ResolutionApplier = Future<void> Function(
  int key,
  ConflictResolution resolution,
);

/// Drives the conflict dialog: per-field choices, the three "apply"
/// shortcuts, and the submitting / done / failed states.
class ConflictResolutionCubit extends ResilientCubit<ConflictResolutionState> {
  ConflictResolutionCubit({
    required OutboxEntry entry,
    required ResolutionApplier apply,
    bool conflictAgain = false,
  }) : _apply = apply,
       super(
         ConflictResolutionIdle(
           entry: entry,
           plan: planFor(entry),
           conflictAgain: conflictAgain,
         ),
       );

  final ResolutionApplier _apply;
  ConflictResolution? _pending;

  ConflictKind get kind => kindOf(state.entry.value);

  /// Chooses the side for one field; the selection is kept across failures.
  void choose(String field, {required bool mine}) {
    final current = state;
    if (current is! ConflictResolutionIdle || _isSubmitting) {
      return;
    }
    emit(
      ConflictResolutionIdle(
        entry: current.entry,
        plan: current.plan,
        choices: {...current.choices, field: mine},
        conflictAgain: current.conflictAgain,
      ),
    );
  }

  bool _isSubmitting = false;

  /// Selects every conflicting field as mine.
  Future<void> keepMine() => _submit(const KeepMine());

  /// Drops my change and keeps the server's.
  Future<void> keepTheirs() => _submit(const KeepTheirs());

  /// Applies the per-field selection.
  Future<void> apply() async {
    final current = state;
    if (current is! ConflictResolutionIdle || !current.complete) {
      return;
    }
    await _submit(MergeFields(current.mineFields));
  }

  /// My queued delete wins over the other writer's edit.
  Future<void> keepDelete() => _submit(const KeepDelete());

  /// My edit loses to the other writer's delete.
  Future<void> acceptDeletion() => _submit(const AcceptDeletion());

  /// Re-runs the choice that failed.
  Future<void> retry() async {
    final pending = _pending;
    if (pending != null) {
      await _submit(pending);
    }
  }

  Future<void> _submit(ConflictResolution resolution) async {
    final current = state;
    // Only a conflict that is still open can be resolved (a second tap after
    // "done" must not resolve twice).
    if (_isSubmitting ||
        current is ConflictResolutionDone ||
        current is ConflictResolutionSubmitting) {
      return;
    }
    _isSubmitting = true;
    _pending = resolution;
    emit(ConflictResolutionSubmitting(entry: state.entry));
    try {
      await _apply(state.entry.key, resolution);
      if (!isClosed) {
        emit(ConflictResolutionDone(entry: state.entry));
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(ConflictResolutionFailed(entry: state.entry, failure: failure));
      }
    } finally {
      _isSubmitting = false;
    }
  }
}
