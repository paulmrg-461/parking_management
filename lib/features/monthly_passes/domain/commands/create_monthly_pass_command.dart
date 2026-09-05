class CreateMonthlyPassCommand {
  const CreateMonthlyPassCommand({
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
  });

  final int vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
}
