import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/bay_sensors/domain/commands/bay_commands.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_occupancy.dart';
import 'package:parking_management/features/bay_sensors/domain/entities/bay_sensor.dart';
import 'package:parking_management/features/bay_sensors/domain/repositories/bay_repository.dart';

BaySensor fakeBaySensor({
  int id = 1,
  int hubDeviceId = 3,
  String hubName = 'Hub',
  int channel = 1,
  int? spotId = 10,
  String? spotCode = 'A1',
  BaySensorType type = BaySensorType.ultrasonic,
  BayState state = BayState.occupied,
  BayHealth health = BayHealth.ok,
  double threshold = 1800,
  double hysteresis = 150,
  double? lastRaw = 900,
  int flaps = 0,
}) {
  return BaySensor(
    id: id,
    hubDeviceId: hubDeviceId,
    hubName: hubName,
    channel: channel,
    spotId: spotId,
    spotCode: spotCode,
    type: type,
    state: state,
    health: health,
    threshold: threshold,
    hysteresis: hysteresis,
    lastRaw: lastRaw,
    lastReportAt: DateTime(2026, 11, 23, 10),
    flapsLastHour: flaps,
  );
}

BayOccupancy fakeBayOccupancy({
  bool sensorsEnabled = true,
  List<BayReading> bays = const [],
  List<BayMismatch> mismatches = const [],
}) => BayOccupancy(
  sensorsEnabled: sensorsEnabled,
  bays: bays,
  mismatches: mismatches,
);

class FakeBayRepository implements BayRepository {
  List<BaySensor> items = [fakeBaySensor()];
  BayOccupancy occupancyValue = fakeBayOccupancy();
  BaySensorSettings settingsValue = const BaySensorSettings();
  Failure? sensorsError;
  Failure? mapError;
  Failure? unmapError;
  Failure? thresholdError;
  Failure? dismissError;
  Failure? settingsError;
  final List<MapBaySensor> mapped = [];
  final List<int> unmapped = [];
  final List<SensorThresholdUpdate> thresholds = [];
  final List<int> dismissed = [];
  final List<BaySensorSettings> savedSettings = [];

  @override
  Future<BayOccupancy> occupancy() async => occupancyValue;

  @override
  Future<({List<BaySensor> mapped, List<BaySensor> unmapped})> sensors() async {
    if (sensorsError case final error?) throw error;
    return (
      mapped: [for (final sensor in items) if (sensor.mapped) sensor],
      unmapped: [for (final sensor in items) if (!sensor.mapped) sensor],
    );
  }

  @override
  Future<BaySensor> mapSensor(MapBaySensor command) async {
    if (mapError case final error?) throw error;
    mapped.add(command);
    items = [
      for (final sensor in items)
        sensor.id == command.sensorId
            ? fakeBaySensor(id: sensor.id, spotId: command.spotId)
            : sensor,
    ];
    return items.firstWhere((sensor) => sensor.id == command.sensorId);
  }

  @override
  Future<void> unmapSensor(int sensorId) async {
    if (unmapError case final error?) throw error;
    unmapped.add(sensorId);
    items = [
      for (final sensor in items)
        sensor.id == sensorId
            ? fakeBaySensor(id: sensor.id, spotId: null, spotCode: null)
            : sensor,
    ];
  }

  @override
  Future<BaySensor> setThreshold(SensorThresholdUpdate update) async {
    if (thresholdError case final error?) throw error;
    thresholds.add(update);
    items = [
      for (final sensor in items)
        sensor.id == update.sensorId
            ? fakeBaySensor(
                id: sensor.id,
                spotId: sensor.spotId,
                threshold: update.threshold,
                hysteresis: update.hysteresis ?? sensor.hysteresis,
              )
            : sensor,
    ];
    return items.firstWhere((sensor) => sensor.id == update.sensorId);
  }

  @override
  Future<void> dismissMismatch(int id, {String? note}) async {
    if (dismissError case final error?) throw error;
    dismissed.add(id);
  }

  @override
  Future<BaySensorSettings> settings() async {
    if (settingsError case final error?) throw error;
    return settingsValue;
  }

  @override
  Future<BaySensorSettings> saveSettings(BaySensorSettings settings) async {
    if (settingsError case final error?) throw error;
    savedSettings.add(settings);
    settingsValue = settings;
    return settings;
  }
}
