import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/conflict/conflict_resolution.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_outbox.dart';
import 'package:parking_management/core/widgets/conflict_resolution_dialog.dart';

import '../../helpers/test_app.dart';

OutboxEntry _vehicleEdit({
  Map<String, dynamic> payload = const {'color': 'blue'},
  Map<String, dynamic> base = const {'color': 'red', 'brand': 'Kia'},
  Map<String, dynamic>? server = const {
    'id': 1,
    'version': 9,
    'color': 'green',
    'brand': 'Kia',
  },
  String kind = 'edited',
  MutationOperation operation = MutationOperation.update,
}) => MapEntry(
  1,
  PendingMutation(
    entityType: MutationEntity.vehicle,
    operation: operation,
    entityId: 1,
    payloadJson: operation == MutationOperation.update
        ? jsonEncode(payload)
        : null,
    enqueuedAt: DateTime.utc(2026, 1, 1),
    baseVersion: 7,
    baseSnapshotJson: jsonEncode(base),
  ).asConflict(kind: kind, serverRow: server),
);

Future<void> _pump(
  WidgetTester tester, {
  required OutboxEntry entry,
  Future<void> Function(int, ConflictResolution)? apply,
  int? seenVersion,
}) async {
  await tester.pumpWidget(
    testApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ConflictResolutionDialog(
                  entry: entry,
                  apply: apply ?? (_, __) async {},
                  seenVersion: seenVersion,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: shows base, mine and theirs for the clashing field', (
    tester,
  ) async {
    await _pump(tester, entry: _vehicleEdit());

    // The label is the one the operator knows from the vehicle form.
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Antes: red'), findsOneWidget);
    expect(find.text('Mío: blue'), findsOneWidget);
    expect(find.text('Del servidor: green'), findsOneWidget);
  });

  testWidgets('Success: apply is disabled until the field is chosen', (
    tester,
  ) async {
    final sent = <ConflictResolution>[];
    await _pump(
      tester,
      entry: _vehicleEdit(),
      apply: (_, r) async => sent.add(r),
    );

    final apply = tester.widget<FilledButton>(
      find.byKey(const Key('conflict-apply')),
    );
    expect(apply.onPressed, isNull);

    await tester.tap(find.byKey(const Key('conflict-mine-color')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('conflict-apply')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('conflict-apply')));
    await tester.pumpAndSettle();

    expect((sent.single as MergeFields).mineFields, {'color'});
  });

  testWidgets('Success: choosing theirs sends the field as not mine', (
    tester,
  ) async {
    final sent = <ConflictResolution>[];
    await _pump(
      tester,
      entry: _vehicleEdit(),
      apply: (_, r) async => sent.add(r),
    );

    await tester.tap(find.byKey(const Key('conflict-theirs-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conflict-apply')));
    await tester.pumpAndSettle();

    expect((sent.single as MergeFields).mineFields, isEmpty);
  });

  testWidgets('Success: keep mine and keep theirs are both offered', (
    tester,
  ) async {
    final sent = <ConflictResolution>[];
    await _pump(
      tester,
      entry: _vehicleEdit(),
      apply: (_, r) async => sent.add(r),
    );

    expect(find.byKey(const Key('conflict-keep-mine')), findsOneWidget);
    expect(find.byKey(const Key('conflict-keep-theirs')), findsOneWidget);

    await tester.tap(find.byKey(const Key('conflict-keep-theirs')));
    await tester.pumpAndSettle();

    expect(sent.single, isA<KeepTheirs>());
  });

  testWidgets('Success: the auto-merged count is shown', (tester) async {
    await _pump(
      tester,
      entry: _vehicleEdit(
        payload: const {'color': 'blue', 'brand': 'Toyota'},
        base: const {'color': 'red', 'brand': 'Kia'},
      ),
    );

    expect(find.textContaining('1 cambio sin choque'), findsOneWidget);
  });

  testWidgets('Security: a deleted row only offers accepting the deletion', (
    tester,
  ) async {
    final sent = <ConflictResolution>[];
    await _pump(
      tester,
      entry: _vehicleEdit(kind: 'deleted', server: null),
      apply: (_, r) async => sent.add(r),
    );

    expect(find.text('Otra persona eliminó este registro.'), findsWidgets);
    expect(find.byKey(const Key('conflict-keep-mine')), findsNothing);

    await tester.tap(find.byKey(const Key('conflict-accept-deletion')));
    await tester.pumpAndSettle();
    // Confirmation first: the deletion is not reversible.
    expect(find.text('Aceptar la eliminación'), findsWidgets);
    await tester.tap(find.text('Aceptar la eliminación').last);
    await tester.pumpAndSettle();

    expect(sent.single, isA<AcceptDeletion>());
  });

  testWidgets('Success: a delete met an edit offers delete or keep', (
    tester,
  ) async {
    final sent = <ConflictResolution>[];
    await _pump(
      tester,
      entry: _vehicleEdit(operation: MutationOperation.delete),
      apply: (_, r) async => sent.add(r),
    );

    expect(
      find.text('Otra persona editó este registro mientras lo eliminabas.'),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('conflict-keep-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar de todos modos'), findsWidgets);
    await tester.tap(find.text('Eliminar de todos modos').last);
    await tester.pumpAndSettle();

    expect(sent.single, isA<KeepDelete>());
  });

  testWidgets('Success: a record changed again says so', (tester) async {
    await _pump(tester, entry: _vehicleEdit(), seenVersion: 5);

    expect(
      find.text('El registro cambió de nuevo. Revisa los valores actuales.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: an error shows a retry action', (tester) async {
    await _pump(
      tester,
      entry: _vehicleEdit(),
      apply: (_, __) async => throw const NetworkFailure('offline'),
    );

    await tester.tap(find.byKey(const Key('conflict-keep-mine')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conflict-retry')), findsOneWidget);
  });

  testWidgets('A11y: tap targets, labels and contrast meet the guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, entry: _vehicleEdit());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
