import '../entities/tariff.dart';

class CreateTariffCommand {
  const CreateTariffCommand({
    required this.categoryId,
    required this.type,
    required this.amount,
    this.startTime,
    this.endTime,
  });

  final int categoryId;
  final TariffType type;
  final int amount;
  final String? startTime;
  final String? endTime;
}
