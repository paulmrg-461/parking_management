import 'package:equatable/equatable.dart';

class WhatsappDaily extends Equatable {
  const WhatsappDaily({
    required this.date,
    required this.sent,
    required this.failed,
  });

  final DateTime date;
  final int sent;
  final int failed;

  factory WhatsappDaily.fromJson(Map<String, dynamic> json) => WhatsappDaily(
    date: DateTime.parse(json['date'] as String),
    sent: (json['sent'] as num?)?.toInt() ?? 0,
    failed: (json['failed'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [date, sent, failed];
}

/// Delivery metrics for customer WhatsApp messages (`rpc/report_whatsapp`).
class WhatsappReport extends Equatable {
  const WhatsappReport({
    this.sent = 0,
    this.failed = 0,
    this.pending = 0,
    this.byDay = const [],
  });

  final int sent;
  final int failed;
  final int pending;
  final List<WhatsappDaily> byDay;

  static const empty = WhatsappReport();

  bool get hasData => sent + failed + pending > 0;

  factory WhatsappReport.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return WhatsappReport(
      sent: value(json['sent']),
      failed: value(json['failed']),
      pending: value(json['pending']),
      byDay: [
        for (final item in (json['by_day'] as List<dynamic>? ?? const []))
          WhatsappDaily.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  @override
  List<Object?> get props => [sent, failed, pending, byDay];
}
