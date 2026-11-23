import 'package:equatable/equatable.dart';

class MapBaySensor extends Equatable {
  const MapBaySensor({required this.spotId, required this.sensorId});

  final int spotId;
  final int sensorId;

  @override
  List<Object?> get props => [spotId, sensorId];
}

class SensorThresholdUpdate extends Equatable {
  const SensorThresholdUpdate({
    required this.sensorId,
    required this.threshold,
    this.hysteresis,
  });

  final int sensorId;
  final double threshold;
  final double? hysteresis;

  @override
  List<Object?> get props => [sensorId, threshold, hysteresis];
}
