import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/create_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/update_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/domain/repositories/monthly_pass_repository.dart';

final samplePass = MonthlyPass(
  id: 1,
  vehicleId: 1,
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 31),
  amount: 100000,
);

class FakeMonthlyPassRepository implements MonthlyPassRepository {
  List<MonthlyPass> passes = [samplePass];
  Failure? listError;
  Failure? writeError;
  final List<int> deleted = [];
  final List<UpdateMonthlyPassCommand> updates = [];
  CreateMonthlyPassCommand? created;

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async =>
      listError == null ? List.of(passes) : throw listError!;

  @override
  Future<MonthlyPass> create(CreateMonthlyPassCommand command) async {
    _throwIfWriteFails();
    created = command;
    final pass = MonthlyPass(
      id: 2,
      vehicleId: command.vehicleId,
      startDate: command.startDate,
      endDate: command.endDate,
      amount: command.amount,
    );
    passes.add(pass);
    return pass;
  }

  @override
  Future<MonthlyPass> update(UpdateMonthlyPassCommand command) async {
    _throwIfWriteFails();
    updates.add(command);
    return samplePass;
  }

  @override
  Future<void> delete(int id) async {
    _throwIfWriteFails();
    deleted.add(id);
  }

  void _throwIfWriteFails() {
    if (writeError != null) {
      throw writeError!;
    }
  }
}
