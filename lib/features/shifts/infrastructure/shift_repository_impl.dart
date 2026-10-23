import '../domain/entities/shift_summary.dart';
import '../domain/repositories/shift_repository.dart';
import 'shift_remote_data_source.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  ShiftRepositoryImpl(this._remote);

  final ShiftRemoteDataSource _remote;

  @override
  Future<ShiftSummary?> current() => _remote.current();

  @override
  Future<ShiftSummary> open(int openingFloat) => _remote.open(openingFloat);

  @override
  Future<ShiftSummary> close({required int countedCash, String? notes}) =>
      _remote.close(countedCash: countedCash, notes: notes);

  @override
  Future<ShiftSummary> addMovement({
    required String type,
    required int amount,
    required String reason,
  }) => _remote.addMovement(type: type, amount: amount, reason: reason);

  @override
  Future<List<ShiftSummary>> history({int limit = 20}) =>
      _remote.history(limit: limit);
}
