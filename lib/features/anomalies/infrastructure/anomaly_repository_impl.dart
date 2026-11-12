import '../domain/entities/anomaly_settings.dart';
import '../domain/entities/cash_anomaly.dart';
import '../domain/repositories/anomaly_repository.dart';
import 'anomaly_remote_data_source.dart';

class AnomalyRepositoryImpl implements AnomalyRepository {
  AnomalyRepositoryImpl(this._remote);

  final AnomalyRemoteDataSource _remote;

  @override
  Future<AnomalyList> list({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
  }) => _remote.list(status: status, rule: rule, severity: severity);

  @override
  Future<CashAnomaly> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  }) => _remote.resolve(id: id, status: status, note: note);

  @override
  Future<AnomalySettings> loadSettings() => _remote.loadSettings();

  @override
  Future<AnomalySettings> saveSettings(AnomalySettings settings) =>
      _remote.saveSettings(settings);
}
