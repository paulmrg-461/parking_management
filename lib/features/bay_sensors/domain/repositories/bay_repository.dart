import '../commands/bay_commands.dart';
import '../entities/bay_occupancy.dart';
import '../entities/bay_sensor.dart';

abstract class BayRepository {
  Future<BayOccupancy> occupancy();

  Future<({List<BaySensor> mapped, List<BaySensor> unmapped})> sensors();

  Future<BaySensor> mapSensor(MapBaySensor command);

  Future<void> unmapSensor(int sensorId);

  Future<BaySensor> setThreshold(SensorThresholdUpdate update);

  Future<void> dismissMismatch(int id, {String? note});

  Future<BaySensorSettings> settings();

  Future<BaySensorSettings> saveSettings(BaySensorSettings settings);
}
