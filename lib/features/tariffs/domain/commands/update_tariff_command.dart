import '../entities/tariff.dart';

class UpdateTariffCommand {
  const UpdateTariffCommand({
    required this.id,
    this.type,
    this.amount,
    this.startTime,
    this.endTime,
    this.active,
  });

  final int id;
  final TariffType? type;
  final int? amount;
  final String? startTime;
  final String? endTime;
  final bool? active;
}
