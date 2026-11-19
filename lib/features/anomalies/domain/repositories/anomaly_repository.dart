import '../entities/anomaly_settings.dart';
import '../entities/cash_anomaly.dart';

/// Admin-only review of the detected cash anomalies. Remote only: reviewing is
/// an online action, never queued.
abstract class AnomalyRepository {
  Future<AnomalyList> list({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
  });

  Future<CashAnomaly> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  });

  Future<AnomalySettings> loadSettings();

  Future<AnomalySettings> saveSettings(AnomalySettings settings);
}
