class UpdateMonthlyPassCommand {
  const UpdateMonthlyPassCommand({
    required this.id,
    this.startDate,
    this.endDate,
    this.amount,
    this.active,
    this.autoRenew,
    this.autoRenewPaymentMethod,
  });

  final int id;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? amount;
  final bool? active;
  final bool? autoRenew;
  final String? autoRenewPaymentMethod;
}
