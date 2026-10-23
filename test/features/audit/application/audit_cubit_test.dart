import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/audit/application/audit_cubit.dart';

import '../../../helpers/fake_audit_repository.dart';

void main() {
  late FakeAuditRepository repository;
  late AuditCubit cubit;

  setUp(() {
    repository = FakeAuditRepository([sampleAudit()]);
    cubit = AuditCubit(repository);
  });

  tearDown(() => cubit.close());

  test('Success: load exposes the audit entries', () async {
    await cubit.load();

    final state = cubit.state as AuditLoaded;
    expect(state.entries.single.tableName, 'tariffs');
    expect(state.entries.single.actor, 'admin');
  });

  test('Success: filters reach the repository and are kept in the state',
      () async {
    final from = DateTime(2026, 10, 1);
    final to = DateTime(2026, 10, 31);

    await cubit.load(from: from, to: to, table: 'users');

    expect(repository.lastFrom, from);
    expect(repository.lastTable, 'users');
    expect((cubit.state as AuditLoaded).table, 'users');
  });

  test('Success: clearing filters drops the previous selection', () async {
    await cubit.load(table: 'users');

    await cubit.load(clearFilters: true);

    expect(repository.lastTable, isNull);
    expect((cubit.state as AuditLoaded).table, isNull);
  });

  test('Failure: a rejected load is an AuditFailure with the code', () async {
    repository.error = const ValidationFailure(
      'AdminRequiredError',
      'AdminRequiredError',
    );

    await cubit.load();

    expect((cubit.state as AuditFailure).failure?.code, 'AdminRequiredError');
  });
}
