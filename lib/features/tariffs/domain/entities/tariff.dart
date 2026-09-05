import 'package:equatable/equatable.dart';

enum TariffType { hourly, daily, nightly, monthly }

class Tariff extends Equatable {
  const Tariff({
    this.id,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.startTime,
    this.endTime,
    this.active = true,
  });

  final int? id;
  final int categoryId;
  final TariffType type;
  final int amount;
  final String? startTime;
  final String? endTime;
  final bool active;

  @override
  List<Object?> get props =>
      [id, categoryId, type, amount, startTime, endTime, active];
}
