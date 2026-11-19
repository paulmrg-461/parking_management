import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';

PendingMutation _update({
  int? baseVersion = 7,
  bool needsResolution = false,
  String? conflictKind,
}) => PendingMutation(
  entityType: MutationEntity.vehicle,
  operation: MutationOperation.update,
  entityId: 5,
  payloadJson: jsonEncode({'color': 'blue'}),
  enqueuedAt: DateTime(2026, 11, 11),
  baseVersion: baseVersion,
  baseSnapshotJson: jsonEncode({'color': 'red', 'brand': 'Kia'}),
  needsResolution: needsResolution,
  conflictKind: conflictKind,
  serverJson: needsResolution
      ? jsonEncode({'version': 9, 'color': 'green'})
      : null,
);

void main() {
  test('Success: the new fields round-trip', () {
    final entry = _update();

    final back = PendingMutation.fromJson(entry.toJson());

    expect(back.baseVersion, 7);
    expect(back.decodeBaseSnapshot()?['color'], 'red');
    expect(back.needsResolution, isFalse);
    expect(back.state, 'pending');
  });

  test('Success: an old JSON entry without the new keys is legacy', () {
    final legacy = {
      'entityType': 'vehicle',
      'operation': 'update',
      'entityId': 5,
      'payloadJson': jsonEncode({'color': 'blue'}),
      'enqueuedAt': DateTime(2026).toIso8601String(),
    };

    final entry = PendingMutation.fromJson(legacy);

    expect(entry.baseVersion, isNull);
    expect(entry.needsResolution, isFalse);
    expect(entry.state, 'pending');
  });

  test('Success: a conflict is written as deadLettered for older builds', () {
    final entry = _update(needsResolution: true, conflictKind: 'edited');

    expect(entry.toJson()['deadLettered'], isTrue);
    // ...but a current build reads it back as a conflict, not a dead letter.
    final back = PendingMutation.fromJson(entry.toJson());
    expect(back.needsResolution, isTrue);
    expect(back.state, 'conflict');
    expect(back.deadLettered, isFalse);
    expect(back.conflictKind, 'edited');
    expect(back.decodeServerRow()?['version'], 9);
  });

  test('Success: the state getter separates the three shapes', () {
    expect(_update().state, 'pending');
    expect(
      _update().recordFailure('boom', deadLettered: true).state,
      'deadLetter',
    );
    expect(
      _update(needsResolution: true, conflictKind: 'deleted').state,
      'conflict',
    );
  });

  test('Failure: recordFailure and withPayload keep the base fields', () {
    final failed = _update().recordFailure('offline');
    expect(failed.baseVersion, 7);
    expect(failed.baseSnapshotJson, isNotNull);

    final payload = _update().withPayload(jsonEncode({'color': 'green'}));
    expect(payload.decodePayload()['color'], 'green');
    expect(payload.baseVersion, 7);
    expect(payload.baseSnapshotJson, isNotNull);
  });

  test('Success: asConflict and rebased build the two resolved shapes', () {
    final conflict = _update().asConflict(
      kind: 'edited',
      serverRow: {'version': 9, 'color': 'green'},
    );
    expect(conflict.needsResolution, isTrue);
    expect(conflict.serverJson, isNotNull);

    final rebased = conflict.rebased(
      baseVersion: 9,
      payloadJson: jsonEncode({'color': 'blue'}),
      baseSnapshotJson: jsonEncode({'version': 9, 'color': 'green'}),
    );
    expect(rebased.needsResolution, isFalse);
    expect(rebased.baseVersion, 9);
    expect(rebased.conflictKind, isNull);
    expect(rebased.attempts, 0);
  });
}
