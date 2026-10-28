import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/records/application/records_cubit.dart';

import '../../../helpers/fake_record_repository.dart';

void main() {
  test('Success: load keeps the server order and total', () async {
    final repository = FakeRecordRepository([
      sampleRecord(id: 1, plate: 'ABC123'),
      sampleRecord(id: 2, plate: 'XYZ999'),
    ]);
    final cubit = RecordsCubit(repository, searchDebounce: Duration.zero);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, RecordsStatus.loaded);
    expect(cubit.state.records, hasLength(2));
    expect(cubit.state.total, 2);
  });

  test('Failure: the plate filter is debounced and sent to the server', () async {
    final repository = FakeRecordRepository([
      sampleRecord(id: 1, plate: 'ABC123'),
      sampleRecord(id: 2, plate: 'XYZ999'),
    ]);
    final cubit = RecordsCubit(repository, searchDebounce: Duration.zero);
    addTearDown(cubit.close);
    await cubit.load();

    cubit.search('abc');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.lastPlate, 'abc');
    expect(cubit.state.records.single.plate, 'ABC123');
  });

  test('Security: paging appends without duplicating rows', () async {
    final repository = FakeRecordRepository([
      for (var i = 0; i < 5; i++) sampleRecord(id: i + 1, plate: 'ABC12$i'),
    ]);
    final cubit = RecordsCubit(
      repository,
      searchDebounce: Duration.zero,
      pageSize: 2,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.records, hasLength(2));

    await cubit.loadMore();

    expect(cubit.state.records, hasLength(4));
    expect(
      cubit.state.records.map((record) => record.id).toSet(),
      hasLength(4),
    );
  });

  test('Failure: a failed load lands in the failure state', () async {
    final repository = FakeRecordRepository([sampleRecord()])
      ..error = const NetworkFailure('offline');
    final cubit = RecordsCubit(repository, searchDebounce: Duration.zero);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, RecordsStatus.failure);
  });

  test('Success: the date range is sent with the next load', () async {
    final repository = FakeRecordRepository([
      sampleRecord(id: 1, plate: 'ABC123', entryTime: DateTime(2026, 10, 20)),
      sampleRecord(id: 2, plate: 'ABC123', entryTime: DateTime(2026, 10, 28)),
    ]);
    final cubit = RecordsCubit(repository, searchDebounce: Duration.zero);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setRange(DateTime(2026, 10, 27), DateTime(2026, 10, 28));

    expect(repository.lastFrom, DateTime(2026, 10, 27));
    expect(repository.lastTo, DateTime(2026, 10, 28));
    expect(cubit.state.records.single.id, 2);

    await cubit.setRange(null, null);
    expect(repository.lastFrom, isNull);
    expect(cubit.state.records, hasLength(2));
  });

  test('Security: exporting walks every page of the filter', () async {
    final repository = FakeRecordRepository([
      for (var i = 0; i < 5; i++) sampleRecord(id: i + 1, plate: 'ABC12$i'),
    ]);
    final cubit = RecordsCubit(
      repository,
      searchDebounce: Duration.zero,
      pageSize: 2,
    );
    addTearDown(cubit.close);
    await cubit.load();

    final rows = await cubit.exportAll();

    expect(rows, hasLength(5));
    expect(rows!.map((row) => row.id).toSet(), hasLength(5));
  });
}
