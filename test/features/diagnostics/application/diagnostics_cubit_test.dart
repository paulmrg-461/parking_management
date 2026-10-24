import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/diagnostics/application/diagnostics_cubit.dart';

import '../../../helpers/fake_diagnostics_repository.dart';

void main() {
  test('Success: load exposes the snapshot and the client errors', () async {
    final cubit = DiagnosticsCubit(
      FakeDiagnosticsRepository(errors: [sampleError()]),
    );
    addTearDown(cubit.close);

    await cubit.load();

    final state = cubit.state as DiagnosticsLoaded;
    expect(state.snapshot.openSessions, 3);
    expect(state.errors.single.message, contains('boom'));
  });

  test('Failure: a rejected load reports the failure code', () async {
    final cubit = DiagnosticsCubit(
      FakeDiagnosticsRepository()
        ..error = const ValidationFailure(
          'AdminRequiredError',
          'AdminRequiredError',
        ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect((cubit.state as DiagnosticsFailure).failure?.code,
        'AdminRequiredError');
  });
}
