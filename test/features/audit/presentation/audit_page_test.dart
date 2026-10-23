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
    expect(find.text('update'), findsOneWidget);
  });

  testWidgets('Empty: no changes shows the empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text('Sin cambios registrados'), findsOneWidget);
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
