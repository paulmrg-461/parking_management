import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';

import '../../../helpers/fake_settings_repository.dart';

const _configured = ParkingSettings(
  name: 'Parqueadero Central',
  address: 'Cra 7 # 12-34',
  logoVersion: 2,
);

void main() {
  late FakeParkingSettingsRepository repository;
  late BrandingCubit cubit;

  setUp(() {
    repository = FakeParkingSettingsRepository();
    cubit = BrandingCubit(repository);
  });

  tearDown(() => cubit.close());

  test('Success: load seeds branding from the cache before any refresh', () async {
    repository
      ..cached = const ParkingSettings(name: 'Parqueadero Central')
      ..logoBytes = Uint8List.fromList(const [1, 2]);
    final emissions = <BrandingState>[];
    final subscription = cubit.stream.listen(emissions.add);

    await cubit.load();
    await subscription.cancel();

    expect(emissions.first, isA<BrandingLoaded>());
    expect(emissions.first.settingsOrNull?.name, 'Parqueadero Central');
    expect(emissions.first.logoOrNull, isNotNull);
  });

  test('Success: load refreshes branding from the backend', () async {
    repository
      ..settings = _configured
      ..logoBytes = Uint8List.fromList(const [9, 9]);

    await cubit.load();

    final loaded = cubit.state as BrandingLoaded;
    expect(loaded.settings, _configured);
    expect(loaded.logo, Uint8List.fromList(const [9, 9]));
  });

  test('Success: an unconfigured record keeps the localized fallback', () async {
    await cubit.load();

    expect(cubit.state, isA<BrandingInitial>());
    expect(cubit.state.settingsOrNull, isNull);
  });

  test('Failure: an offline first run keeps the initial state', () async {
    repository.loadError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, isA<BrandingInitial>());
  });
}
