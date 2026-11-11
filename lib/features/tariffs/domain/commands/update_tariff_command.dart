import '../entities/tariff.dart';

class UpdateTariffCommand {
  const UpdateTariffCommand({
    required this.id,
    this.type,
    this.amount,
    this.startTime,
    this.endTime,
    this.active,
    this.baseVersion,
  });

  final int id;
  final TariffType? type;
  final int? amount;
  final String? startTime;
  final String? endTime;
  final bool? active;

  /// The row version the editor opened (`null` = use the cached one).
  final int? baseVersion;
}
