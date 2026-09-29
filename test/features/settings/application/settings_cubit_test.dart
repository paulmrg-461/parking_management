import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/settings/application/settings_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';

import '../../../helpers/fake_settings_repository.dart';

const _configured = ParkingSettings(
  name: 'Parqueadero Central',
  address: 'Cra 7 # 12-34',
);

void main() {
  late FakeParkingSettingsRepository repository;
  late SettingsCubit cubit;

  setUp(() {
    repository = FakeParkingSettingsRepository(_configured);
    cubit = SettingsCubit(repository);
  });

  tearDown(() => cubit.close());

  ParkingSettings current() => (cubit.state as SettingsLoaded).settings;

  test('Success: load exposes the fetched settings', () async {
    await cubit.load();

    expect(cubit.state, isA<SettingsLoaded>());
    expect(current().name, 'Parqueadero Central');
    expect(current().address, 'Cra 7 # 12-34');
  });

  test('Success: save updates the state with the new values', () async {
    await cubit.load();

    await cubit.save(current().copyWith(name: 'Parqueadero Sur'));

    expect(current().name, 'Parqueadero Sur');
    expect(
      (cubit.state as SettingsLoaded).submission,
      isA<SubmissionSucceeded>(),
    );
  });

  test('Failure: a failed save keeps the data and reports the failure', () async {
    await cubit.load();
    repository.saveError = const ServerFailure('invalid name');

    await cubit.save(current().copyWith(name: 'Nope'));

    final loaded = cubit.state as SettingsLoaded;
    expect(loaded.settings.name, 'Parqueadero Central');
    expect(loaded.submission, isA<SubmissionFailed>());
    expect((loaded.submission as SubmissionFailed).message, 'invalid name');
  });
}
