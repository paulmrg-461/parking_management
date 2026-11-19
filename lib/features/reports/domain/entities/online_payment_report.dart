import 'package:equatable/equatable.dart';

/// One approved (or voided) online payment, as the bank sees it.
class OnlinePaymentItem extends Equatable {
  const OnlinePaymentItem({
    required this.intentId,
    required this.reference,
    required this.amount,
    this.transactionId,
    this.method,
    this.approvedAt,
    this.sessionId,
    this.plate = '',
    this.ticketNumber,
    this.status = 'approved',
  });

  final int intentId;
  final String reference;
  final String? transactionId;
  final String? method;
  final int amount;
  final DateTime? approvedAt;
  final int? sessionId;
  final String plate;
  final String? ticketNumber;

  /// `approved` (money in) or `voided` (refunded / reversed).
  final String status;

  factory OnlinePaymentItem.fromJson(Map<String, dynamic> json) =>
      OnlinePaymentItem(
        intentId: (json['intent_id'] as num?)?.toInt() ?? 0,
        reference: json['reference'] as String? ?? '',
        transactionId: json['gateway_transaction_id'] as String?,
        method: json['gateway_method'] as String?,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
        sessionId: (json['session_id'] as num?)?.toInt(),
        plate: json['plate'] as String? ?? '',
        ticketNumber: json['ticket_number'] as String?,
        status: json['status'] as String? ?? 'approved',
      );

  @override
  List<Object?> get props => [
    intentId,
    reference,
    transactionId,
    method,
    amount,
    approvedAt,
    sessionId,
    plate,
    ticketNumber,
    status,
  ];
}

/// Online money of a business-date window (`rpc/report_online_payments`).
/// `total`/`count` are the approved rows; `items` also lists voided ones so a
/// refund is traceable.
class OnlinePaymentReport extends Equatable {
  const OnlinePaymentReport({
    this.total = 0,
    this.count = 0,
    this.items = const [],
  });

  final int total;
  final int count;
  final List<OnlinePaymentItem> items;

  static const empty = OnlinePaymentReport();

  bool get hasData => items.isNotEmpty;

  factory OnlinePaymentReport.fromJson(Map<String, dynamic> json) =>
      OnlinePaymentReport(
        total: (json['total'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
        items: [
          for (final item in (json['items'] as List? ?? const []))
            if (item is Map)
              OnlinePaymentItem.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  @override
  List<Object?> get props => [total, count, items];
}
