import '../domain/entities/loyalty_account.dart';
import '../domain/entities/loyalty_report.dart';
import '../domain/entities/loyalty_settings.dart';
import '../domain/entities/loyalty_status.dart';
import '../domain/repositories/loyalty_repository.dart';
import 'loyalty_remote_data_source.dart';

class LoyaltyRepositoryImpl implements LoyaltyRepository {
  LoyaltyRepositoryImpl(this._remote);

  final LoyaltyRemoteDataSource _remote;

  @override
  Future<LoyaltyStatus> status(String plate) => _remote.status(plate);

  @override
  Future<LoyaltySettings> loadSettings() => _remote.loadSettings();

  @override
  Future<LoyaltySettings> saveSettings(LoyaltySettings settings) =>
      _remote.saveSettings(settings);

  @override
  Future<void> choose({
    required int sessionId,
    required LoyaltyChoice choice,
  }) => _remote.choose(sessionId: sessionId, choice: choice);

  @override
  Future<List<LoyaltyAccount>> accounts({String? search}) =>
      _remote.accounts(search: search);

  @override
  Future<LoyaltyAdjustResult> adjust({
    required String plate,
    required int delta,
    required String reason,
  }) => _remote.adjust(plate: plate, delta: delta, reason: reason);

  @override
  Future<LoyaltyReport> report({
    required DateTime start,
    required DateTime end,
  }) => _remote.report(start: start, end: end);
}
