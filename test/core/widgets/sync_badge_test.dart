import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/conflict/conflict_resolution.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_status_cubit.dart';
import 'package:parking_management/core/widgets/sync_badge.dart';

import '../../helpers/fake_sync_outbox.dart';
import '../../helpers/test_app.dart';

PendingMutation _mutation({bool dead = false}) => PendingMutation(
  entityType: MutationEntity.checkOut,
  operation: MutationOperation.close,
  entityId: 5,
  payloadJson: '{}',
  enqueuedAt: DateTime.utc(2026, 1, 1),
  lastError: dead ? 'Session already closed' : null,
  deadLettered: dead,
);

Future<SyncStatusCubit> _pump(
  WidgetTester tester,
  FakeSyncOutbox outbox, {
  List<(int, ConflictResolution)>? resolved,
}) async {
  final cubit = SyncStatusCubit(
    outbox,
    outbox.remove,
    null,
    resolved == null
        ? null
        : (key, resolution) async {
            resolved.add((key, resolution));
            await outbox.remove(key);
          },
  );
  await tester.runAsync(cubit.load);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: Scaffold(appBar: AppBar(actions: const [SyncBadge()])),
      ),
    ),
  );
  return cubit;
}

void main() {
  testWidgets('Success: shows the pending count with an accessible tooltip', (
    tester,
  ) async {
    final outbox = FakeSyncOutbox();
    await outbox.enqueue(_mutation());
    await outbox.enqueue(_mutation());

    await _pump(tester, outbox);

    expect(find.text('2'), findsOneWidget);
    expect(
      find.byTooltip('2 cambios pendientes de sincronizar'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: tapping lists dead letters and discard removes them', (
    tester,
  ) async {
    final outbox = FakeSyncOutbox();
    await outbox.enqueue(_mutation(dead: true));
    await _pump(tester, outbox);

    await tester.tap(find.byType(SyncBadge));
    await tester.pumpAndSettle();
    expect(find.text('Session already closed'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Descartar cambio'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();

    expect(outbox.all, isEmpty);
    expect(find.text('Session already closed'), findsNothing);
  });

  testWidgets('Security: renders nothing when the queue is empty', (
    tester,
  ) async {
    await _pump(tester, FakeSyncOutbox());

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('Success: a conflict shows the merge icon and can be resolved', (
    tester,
  ) async {
    final outbox = FakeSyncOutbox();
    await outbox.enqueue(
      _mutation().asConflict(
        kind: 'edited',
        serverRow: {'id': 5, 'version': 9},
      ),
    );
    final resolved = <(int, ConflictResolution)>[];

    await _pump(tester, outbox, resolved: resolved);

    expect(find.byIcon(Icons.merge_type), findsOneWidget);
    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();
    expect(find.text('Requieren tu decisión'), findsOneWidget);
    await tester.tap(find.text('Otra persona cambió este registro.'));
    await tester.pumpAndSettle();
    expect(find.text('Resolver conflicto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('conflict-keep-mine')));
    await tester.pumpAndSettle();

    expect(resolved.single.$2, isA<KeepMine>());
    expect(await outbox.listConflicts(), isEmpty);
  });
}
