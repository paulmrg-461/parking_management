import '../commands/create_monthly_pass_command.dart';
import '../commands/update_monthly_pass_command.dart';
import '../entities/monthly_pass.dart';
import '../entities/monthly_pass_payment.dart';

abstract class MonthlyPassRepository {
  Future<List<MonthlyPass>> list({int? vehicleId});

  Future<MonthlyPass> create(CreateMonthlyPassCommand command);

  Future<MonthlyPass> update(UpdateMonthlyPassCommand command);

  Future<void> delete(int id);

  Future<List<MonthlyPassPayment>> pendingPayments();

  Future<MonthlyPassPayment> registerPayment(int id, String method);
}
