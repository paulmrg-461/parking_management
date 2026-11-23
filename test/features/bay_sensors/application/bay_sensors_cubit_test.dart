import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/bay_sensors/application/bay_sensors_cubit.dart';
import 'package:parking_management/features/bay_sensors/domain/commands/bay_commands.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_sensor.dart';

import '../../../helpers/fake_bay_repository.dart';

void main() {
  test('load splits the sensors', () async {
    final repository = FakeBayRepository()
      ..items = [fakeBaySensor(id: 1), fakeBaySensor(id: 2, spotId: null)];
    final cubit = BaySensorsCubit(repository);
    await cubit.load();
    final state = cubit.state as BaySensorsLoaded;
    expect(state.mapped.single.id, 1);
    expect(state.unmapped.single.id, 2);
    expect(state.forSpot(10)?.id, 1);
    await cubit.close();
  });

  test('no channels emits the empty state', () async {
    final cubit = BaySensorsCubit(FakeBayRepository()..items = []);
    await cubit.load();
    expect(cubit.state, isA<BaySensorsEmpty>());
    await cubit.close();
  });

  test('a failure keeps the retry path', () async {
    final cubit = BaySensorsCubit(
      FakeBayRepository()..sensorsError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<BaySensorsFailure>());
    await cubit.close();
  });

  test('mapping refreshes the lists', () async {
    final repository = FakeBayRepository()
      ..items = [fakeBaySensor(id: 5, spotId: null, spotCode: null)];
    final cubit = BaySensorsCubit(repository);
    await cubit.load();
    await cubit.map(const MapBaySensor(spotId: 10, sensorId: 5));
    final state = cubit.state as BaySensorsLoaded;
    expect(repository.mapped.single.sensorId, 5);
    expect(state.mapped.single.spotId, 10);
    expect(state.submission, isA<SubmissionSucceeded>());
    await cubit.close();
  });

  test('a map failure reports it', () async {
    final repository = FakeBayRepository()
      ..items = [fakeBaySensor(id: 5, spotId: null)]
      ..mapError = const ValidationFailure('taken');
    final cubit = BaySensorsCubit(repository);
    await cubit.load();
    await cubit.map(const MapBaySensor(spotId: 10, sensorId: 5));
    expect((cubit.state as BaySensorsLoaded).submission, isA<SubmissionFailed>());
    await cubit.close();
  });

  test('unmap and threshold refresh the sensor', () async {
    final repository = FakeBayRepository();
    final cubit = BaySensorsCubit(repository);
    await cubit.load();
    await cubit.unmap(1);
    expect(repository.unmapped.single, 1);
    expect((cubit.state as BaySensorsLoaded).mapped, isEmpty);
    await cubit.load();
    final restored = FakeBayRepository();
    final second = BaySensorsCubit(restored);
    await second.load();
    await second.setThreshold(
      const SensorThresholdUpdate(sensorId: 1, threshold: 2100),
    );
    expect(restored.thresholds.single.threshold, 2100);
    expect((second.state as BaySensorsLoaded).mapped.single.threshold, 2100);
    await cubit.close();
    await second.close();
  });
}
