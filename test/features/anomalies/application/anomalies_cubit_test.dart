import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/anomalies/application/anomalies_cubit.dart';
import 'package:parking_management/features/anomalies/domain/entities/cash_anomaly.dart';

import '../../../helpers/fake_anomaly_repository.dart';

void main() {
  test('Success: load emits loading then loaded with the open filter', () async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    final cubit = AnomaliesCubit(repository);
    final states = <AnomaliesState>[];
    cubit.stream.listen(states.add);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<AnomaliesLoading>());
    final loaded = states.last as AnomaliesLoaded;
    expect(loaded.list.items, hasLength(1));
    expect(loaded.status, AnomalyStatus.open);
    expect(repository.statuses.single, AnomalyStatus.open);
  });

  test('Success: an empty list is a loaded state', () async {
    final cubit = AnomaliesCubit(FakeAnomalyRepository());

    await cubit.load();

    final loaded = cubit.state as AnomaliesLoaded;
    expect(loaded.list.isEmpty, isTrue);
  });

  test('Success: filters persist across loads and clearFilters resets', () async {
    final repository = FakeAnomalyRepository();
    final cubit = AnomaliesCubit(repository);

    await cubit.load(severity: AnomalySeverity.high);
    await cubit.load();
    expect((cubit.state as AnomaliesLoaded).severity, AnomalySeverity.high);

    await cubit.load(clearFilters: true);
    final reset = cubit.state as AnomaliesLoaded;
    expect(reset.severity, isNull);
    expect(reset.rule, isNull);
  });

  test('Success: resolve reloads with the same filters', () async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    final cubit = AnomaliesCubit(repository);
    await cubit.load(severity: AnomalySeverity.high);

    await cubit.resolve(id: 1, status: AnomalyStatus.acknowledged);

    expect(repository.resolved.single.$2, AnomalyStatus.acknowledged);
    expect((cubit.state as AnomaliesLoaded).severity, AnomalySeverity.high);
  });

  test('Failure: load failure emits AnomaliesFailure', () async {
    final cubit = AnomaliesCubit(
      FakeAnomalyRepository()..listError = const NetworkFailure('offline'),
    );

    await cubit.load();

    expect(cubit.state, isA<AnomaliesFailure>());
  });

  test('Failure: a resolve failure keeps the list and sets a notice', () async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1)
      ..resolveError = const ValidationFailure(
        'AnomalyNoteRequiredError',
        'AnomalyNoteRequiredError',
      );
    final cubit = AnomaliesCubit(repository);
    await cubit.load();

    await cubit.resolve(id: 1, status: AnomalyStatus.dismissed);

    final loaded = cubit.state as AnomaliesLoaded;
    expect(loaded.list.items, hasLength(1));
    expect(loaded.notice?.code, 'AnomalyNoteRequiredError');
    expect(loaded.resolvingId, isNull);
  });

  test('Security: AdminRequiredError becomes a failure with its code', () async {
    final cubit = AnomaliesCubit(
      FakeAnomalyRepository()
        ..listError = const ValidationFailure(
          'AdminRequiredError',
          'AdminRequiredError',
        ),
    );

    await cubit.load();

    expect((cubit.state as AnomaliesFailure).failure.code, 'AdminRequiredError');
  });
}
