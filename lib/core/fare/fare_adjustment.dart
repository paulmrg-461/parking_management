import 'package:equatable/equatable.dart';

/// Kind of automatic fare line. Unknown values are kept forward-compatible
/// (a newer backend may add kinds this build does not know).
enum FareAdjustmentType { merchant, reward, unknown }

FareAdjustmentType fareAdjustmentTypeFromWire(String? value) =>
    switch (value) {
      'merchant' => FareAdjustmentType.merchant,
      'reward' => FareAdjustmentType.reward,
      _ => FareAdjustmentType.unknown,
    };

/// One automatic reduction of the fare (`parking_sessions.fare_adjustments`).
/// `refId` points at the merchant validation (or the future reward row).
class FareAdjustment extends Equatable {
  const FareAdjustment({
    required this.type,
    required this.refId,
    required this.label,
    required this.kind,
    required this.amount,
  });

  final FareAdjustmentType type;
  final int refId;
  final String label;

  /// `free_minutes`, `percentage`, `fixed_amount` or a future reward kind.
  final String kind;
  final int amount;

  factory FareAdjustment.fromJson(Map<String, dynamic> json) => FareAdjustment(
    type: fareAdjustmentTypeFromWire(json['type'] as String?),
    refId: (json['ref_id'] as num?)?.toInt() ?? 0,
    label: json['label'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
  );

  static List<FareAdjustment> listFromJson(Object? raw) => [
    for (final item in (raw as List? ?? const []))
      if (item is Map) FareAdjustment.fromJson(Map<String, dynamic>.from(item)),
  ];

  @override
  List<Object?> get props => [type, refId, label, kind, amount];
}
