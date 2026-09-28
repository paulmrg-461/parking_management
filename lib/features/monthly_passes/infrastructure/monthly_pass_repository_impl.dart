import '../../../core/error/failure.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/repositories/monthly_pass_repository.dart';
import 'monthly_pass_local_data_source.dart';
import 'monthly_pass_remote_data_source.dart';

class MonthlyPassRepositoryImpl implements MonthlyPassRepository {
  MonthlyPassRepositoryImpl(this._remote, this._local);

  final MonthlyPassRemoteDataSource _remote;
  final MonthlyPassLocalDataSource _local;

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
    try {
      final monthlyPasses = await _remote.list(vehicleId: vehicleId);
      await _local.cacheAll(monthlyPasses);
      return monthlyPasses;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<MonthlyPass> create(CreateMonthlyPassCommand command) async {
    return _remote.create(_toCreatePayload(command));
  }

  @override
  Future<MonthlyPass> update(UpdateMonthlyPassCommand command) async {
    return _remote.update(command.id, _toUpdatePayload(command));
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(id);
  }

  Map<String, dynamic> _toCreatePayload(CreateMonthlyPassCommand command) => {
    'vehicle_id': command.vehicleId,
    'start_date': _formatDate(command.startDate),
    'end_date': _formatDate(command.endDate),
    'amount': command.amount,
  };

  Map<String, dynamic> _toUpdatePayload(UpdateMonthlyPassCommand command) => {
    if (command.startDate != null)
      'start_date': _formatDate(command.startDate!),
    if (command.endDate != null) 'end_date': _formatDate(command.endDate!),
    if (command.amount != null) 'amount': command.amount,
    if (command.active != null) 'active': command.active,
  };

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
