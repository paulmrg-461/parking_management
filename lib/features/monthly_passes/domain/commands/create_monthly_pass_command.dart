class CreateMonthlyPassCommand {
  const CreateMonthlyPassCommand({
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.autoRenew = false,
  });

  final int vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
  final bool autoRenew;
}
