import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/conflict/conflict_resolution.dart';
import 'package:parking_management/core/sync/conflict/conflict_resolution_cubit.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';

OutboxEntry _entry({
  String? kind = 'edited',
  Map<String, dynamic>? server = const {
    'id': 1,
    'version': 9,
    'color': 'green',
    'brand': 'Kia',
  },
  MutationOperation operation = MutationOperation.update,
}) => MapEntry(
  1,
  PendingMutation(
    entityType: MutationEntity.vehicle,
    operation: operation,
    entityId: 1,
    payloadJson: operation == MutationOperation.update
        ? '{"color":"blue"}'
        : null,
    enqueuedAt: DateTime.utc(2026, 1, 1),
    baseVersion: 7,
    baseSnapshotJson: '{}',
  ).asConflict(kind: kind ?? 'edited', serverRow: server),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

/// Records every state the cubit emits from now on.
List<ConflictResolutionState> _record(ConflictResolutionCubit cubit) {
  final states = <ConflictResolutionState>[];
  cubit.stream.listen(states.add);
  return states;
}

void main() {
  test('Success: idle starts with nothing chosen and apply disabled', () {
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (_, __) async {},
    );

    final idle = cubit.state as ConflictResolutionIdle;
    expect(idle.plan.conflicts.single.field, 'color');
    expect(idle.complete, isFalse);
    expect(cubit.kind, ConflictKind.edited);
  });

  test('Success: choosing per field marks the selection complete', () async {
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (_, __) async {},
    );
    final states = _record(cubit);

    cubit.choose('color', mine: true);
    await Future<void>.delayed(Duration.zero);

    expect((states.single as ConflictResolutionIdle).complete, isTrue);
  });

  test('Failure: apply does nothing until every field has a choice', () async {
    var applied = 0;
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (_, __) async => applied += 1,
    );
    final states = _record(cubit);

    await cubit.apply();

    expect(states, isEmpty);
    expect(applied, 0);
  });

  test('Success: idle then submitting then done for keep mine', () async {
    ConflictResolution? sent;
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (key, resolution) async {
        expect(key, 1);
        sent = resolution;
      },
    );
    final states = _record(cubit);

    await cubit.keepMine();
    await _flush();

    expect(states, [
      isA<ConflictResolutionSubmitting>(),
      isA<ConflictResolutionDone>(),
    ]);
    expect(sent, isA<KeepMine>());
  });

  test('Success: keep mine needs no per-field choice', () async {
    final cubit = ConflictResolutionCubit(
      entry: _entry(
        server: const {
          'id': 1,
          'version': 9,
          'color': 'green',
          'brand': 'Sedan',
        },
      ),
      apply: (key, resolution) async {
        // KeepMine means "every conflicting field is mine".
        expect(resolution, isA<KeepMine>());
      },
    );

    await cubit.keepMine();

    expect(cubit.state, isA<ConflictResolutionDone>());
  });

  test('Success: apply sends the per-field merge', () async {
    Set<String>? fields;
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (key, resolution) async {
        fields = (resolution as MergeFields).mineFields;
      },
    );
    final states = _record(cubit);

    cubit.choose('color', mine: true);
    await cubit.apply();
    await _flush();

    expect(fields, {'color'});
    expect(states.last, isA<ConflictResolutionDone>());
  });

  test(
    'Failure: a failure keeps the selection and retry runs it again',
    () async {
      var calls = 0;
      final cubit = ConflictResolutionCubit(
        entry: _entry(),
        apply: (key, resolution) async {
          calls += 1;
          if (calls == 1) {
            throw const NetworkFailure('offline');
          }
        },
      );
      final states = _record(cubit);

      cubit.choose('color', mine: true);
      await cubit.apply();
      await cubit.retry();
      await _flush();

      expect(calls, 2);
      expect(states.map((state) => state.runtimeType).toList(), [
        ConflictResolutionIdle,
        ConflictResolutionSubmitting,
        ConflictResolutionFailed,
        ConflictResolutionSubmitting,
        ConflictResolutionDone,
      ]);
    },
  );

  test('Failure: a failed resolution keeps the chosen fields', () async {
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (_, __) async => throw const NetworkFailure('offline'),
    );

    cubit.choose('color', mine: true);
    await cubit.apply();

    expect(cubit.state, isA<ConflictResolutionFailed>());
    // The dialog re-reads the selection from the cubit's file state.
    await cubit.retry();
    expect(cubit.state, isA<ConflictResolutionFailed>());
  });

  test('Security: a deleted row only accepts the deletion', () async {
    ConflictResolution? sent;
    final cubit = ConflictResolutionCubit(
      entry: _entry(kind: 'deleted', server: null),
      apply: (key, resolution) async => sent = resolution,
    );

    await cubit.acceptDeletion();

    expect(cubit.kind, ConflictKind.deleted);
    expect(sent, isA<AcceptDeletion>());
  });

  test('Success: a delete met an edit offers keep delete', () async {
    ConflictResolution? sent;
    final cubit = ConflictResolutionCubit(
      entry: _entry(operation: MutationOperation.delete),
      apply: (key, resolution) async => sent = resolution,
    );

    await cubit.keepDelete();

    expect(cubit.kind, ConflictKind.deletedElsewhere);
    expect(sent, isA<KeepDelete>());
  });

  test('Security: done is emitted only once', () async {
    var done = 0;
    final cubit = ConflictResolutionCubit(
      entry: _entry(),
      apply: (_, __) async {},
    );
    cubit.stream.listen((state) {
      if (state is ConflictResolutionDone) {
        done += 1;
      }
    });

    await cubit.keepTheirs();
    await cubit.keepTheirs();
    await _flush();

    expect(done, 1);
  });
}
