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
    this.version = 0,
  });

  final int? id;
  final int categoryId;
  final TariffType type;
  final int amount;
  final String? startTime;
  final String? endTime;
  final bool active;

  /// Row version from the server (`0` when unknown); offline edits send it so
  /// a concurrent change is a conflict, not an overwrite.
  final int version;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    type,
    amount,
    startTime,
    endTime,
    active,
    version,
  ];
}
