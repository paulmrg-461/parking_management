import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/audit/application/audit_cubit.dart';
import 'package:parking_management/features/audit/presentation/audit_page.dart';

import '../../../helpers/fake_audit_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeAuditRepository> pumpPage(
  WidgetTester tester, {
  List<dynamic> entries = const [],
}) async {
  final repository = FakeAuditRepository([
    for (final entry in entries) entry,
  ]);
  final cubit = AuditCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(value: cubit, child: const AuditPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('Success: entries show table, actor and action', (tester) async {
    await pumpPage(tester, entries: [sampleAudit()]);

    expect(find.text('tariffs #3'), findsOneWidget);
    expect(find.textContaining('admin'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets('Empty: no changes shows the empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text('Sin cambios registrados'), findsOneWidget);
  });

  testWidgets('Success: a row opens the before/after comparison', (
    tester,
  ) async {
    await pumpPage(tester, entries: [sampleAudit()]);

    await tester.tap(find.text('tariffs #3'));
    await tester.pumpAndSettle();

    expect(find.text('Cambios'), findsOneWidget);
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Después'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('6000'), findsOneWidget);
  });

  testWidgets('Failure: filters with no results offer to clear them', (
    tester,
  ) async {
    await pumpPage(tester, entries: [sampleAudit()]);

    await tester.tap(find.text('Actor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('admin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('tariffs #3'), findsOneWidget);
  });

  testWidgets('Success: the export menu offers PDF and CSV', (tester) async {
    await pumpPage(tester, entries: [sampleAudit()]);

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(find.text('Exportar PDF'), findsOneWidget);
    expect(find.text('Copiar CSV'), findsOneWidget);
  });

  testWidgets('Success: the actor filter reloads with the selection', (
    tester,
  ) async {
    final repository = await pumpPage(
      tester,
      entries: [sampleAudit(), sampleAudit(id: 2, actor: 'juan')],
    );

    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('juan').last);
    await tester.pumpAndSettle();

    expect(repository.lastActor, 'juan');
  });

  testWidgets('Success: the table filter reloads with the selection', (
    tester,
  ) async {
    final repository = await pumpPage(tester, entries: [sampleAudit()]);

    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('users').last);
    await tester.pumpAndSettle();

    expect(repository.lastTable, 'users');
  });
}
