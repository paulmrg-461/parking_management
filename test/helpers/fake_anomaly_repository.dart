import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/anomalies/domain/entities/anomaly_settings.dart';
import 'package:parking_management/features/anomalies/domain/entities/cash_anomaly.dart';
import 'package:parking_management/features/anomalies/domain/repositories/anomaly_repository.dart';

/// In-memory [AnomalyRepository] for cubit and widget tests.
class FakeAnomalyRepository implements AnomalyRepository {
  AnomalyList listToReturn = AnomalyList.empty;
  AnomalySettings settingsToReturn = AnomalySettings.defaults;
  Failure? listError;
  Failure? resolveError;
  Failure? settingsError;
  final List<AnomalyStatus?> statuses = [];
  final List<(int, AnomalyStatus, String?)> resolved = [];
  final List<AnomalySettings> saved = [];

  @override
  Future<AnomalyList> list({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
  }) async {
    statuses.add(status);
    final error = listError;
    if (error != null) {
      throw error;
    }
    return listToReturn;
  }

  @override
  Future<CashAnomaly> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  }) async {
    final error = resolveError;
    if (error != null) {
      throw error;
    }
    resolved.add((id, status, note));
    final anomaly = listToReturn.items.firstWhere((item) => item.id == id);
    return CashAnomaly(
      id: anomaly.id,
      rule: anomaly.rule,
      severity: anomaly.severity,
      status: status,
      detectedAt: anomaly.detectedAt,
      details: anomaly.details,
      note: note,
    );
  }

  @override
  Future<AnomalySettings> loadSettings() async {
    final error = settingsError;
    if (error != null) {
      throw error;
    }
    return settingsToReturn;
  }

  @override
  Future<AnomalySettings> saveSettings(AnomalySettings settings) async {
    final error = settingsError;
    if (error != null) {
      throw error;
    }
    saved.add(settings);
    return settings;
  }
}

CashAnomaly anomaly({
  int id = 1,
  AnomalyRule rule = AnomalyRule.zeroCharge,
  AnomalySeverity severity = AnomalySeverity.high,
  AnomalyStatus status = AnomalyStatus.open,
  String? plate = 'ABC123',
  Map<String, dynamic> details = const {'payment_method': 'exempt'},
}) => CashAnomaly(
  id: id,
  rule: rule,
  severity: severity,
  status: status,
  detectedAt: DateTime(2026, 11, 10, 9),
  plate: plate,
  operatorName: 'Ana',
  details: details,
);
