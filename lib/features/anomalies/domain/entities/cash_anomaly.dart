import 'package:equatable/equatable.dart';

/// The eight deterministic rules the backend evaluates.
enum AnomalyRule {
  shiftShortage('shift_shortage'),
  lostTicketRate('lost_ticket_rate'),
  postCloseAdjustment('post_close_adjustment'),
  zeroCharge('zero_charge'),
  shortLostTicket('short_lost_ticket'),
  discountRate('discount_rate'),
  shiftOpenLong('shift_open_long'),
  sessionOpenLong('session_open_long');

  const AnomalyRule(this.wire);

  final String wire;

  static AnomalyRule? tryParse(String? value) {
    for (final rule in values) {
      if (rule.wire == value) {
        return rule;
      }
    }
    return null;
  }
}

enum AnomalySeverity {
  low('low'),
  medium('medium'),
  high('high');

  const AnomalySeverity(this.wire);

  final String wire;

  static AnomalySeverity parse(String? value) => switch (value) {
    'high' => AnomalySeverity.high,
    'medium' => AnomalySeverity.medium,
    _ => AnomalySeverity.low,
  };
}

enum AnomalyStatus {
  open('open'),
  acknowledged('acknowledged'),
  dismissed('dismissed');

  const AnomalyStatus(this.wire);

  final String wire;

  static AnomalyStatus parse(String? value) => switch (value) {
    'acknowledged' => AnomalyStatus.acknowledged,
    'dismissed' => AnomalyStatus.dismissed,
    _ => AnomalyStatus.open,
  };
}

/// One detected anomaly (`rpc/list_cash_anomalies`).
class CashAnomaly extends Equatable {
  const CashAnomaly({
    required this.id,
    required this.rule,
    required this.severity,
    required this.status,
    required this.detectedAt,
    this.operatorId,
    this.operatorName,
    this.shiftId,
    this.sessionId,
    this.plate,
    this.details = const {},
    this.resolvedAt,
    this.resolvedByName,
    this.note,
  });

  final int id;
  final AnomalyRule rule;
  final AnomalySeverity severity;
  final AnomalyStatus status;
  final DateTime detectedAt;
  final int? operatorId;
  final String? operatorName;
  final int? shiftId;
  final int? sessionId;
  final String? plate;
  final Map<String, dynamic> details;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? note;

  bool get isOpen => status == AnomalyStatus.open;

  /// A numeric detail (`0` when absent).
  int detailInt(String key) => (details[key] as num?)?.toInt() ?? 0;

  /// A numeric detail as double (`null` when absent).
  double? detailDouble(String key) =>
      details[key] is num ? (details[key] as num).toDouble() : null;

  /// A textual detail (`''` when absent).
  String detailText(String key) => details[key]?.toString() ?? '';

  factory CashAnomaly.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? raw) =>
        raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    final details = json['details'];
    return CashAnomaly(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rule: AnomalyRule.tryParse(json['rule'] as String?) ??
          AnomalyRule.zeroCharge,
      severity: AnomalySeverity.parse(json['severity'] as String?),
      status: AnomalyStatus.parse(json['status'] as String?),
      detectedAt: date(json['detected_at']) ?? DateTime(1970),
      operatorId: (json['operator_id'] as num?)?.toInt(),
      operatorName: json['operator_name'] as String?,
      shiftId: (json['shift_id'] as num?)?.toInt(),
      sessionId: (json['session_id'] as num?)?.toInt(),
      plate: json['plate'] as String?,
      details: details is Map
          ? Map<String, dynamic>.from(details)
          : const {},
      resolvedAt: date(json['resolved_at']),
      resolvedByName: json['resolved_by_name'] as String?,
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    rule,
    severity,
    status,
    detectedAt,
    operatorId,
    operatorName,
    shiftId,
    sessionId,
    plate,
    details,
    resolvedAt,
    resolvedByName,
    note,
  ];
}

/// One page of anomalies plus the lot's open count (ignores the filters).
class AnomalyList extends Equatable {
  const AnomalyList({this.items = const [], this.openCount = 0});

  final List<CashAnomaly> items;
  final int openCount;

  static const empty = AnomalyList();

  bool get isEmpty => items.isEmpty;

  factory AnomalyList.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) {
      return AnomalyList(
        openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      );
    }
    return AnomalyList(
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      items: [
        for (final item in raw)
          if (item is Map) CashAnomaly.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  @override
  List<Object?> get props => [items, openCount];
}
