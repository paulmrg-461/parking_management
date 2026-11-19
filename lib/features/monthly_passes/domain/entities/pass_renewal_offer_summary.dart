import 'package:equatable/equatable.dart';

/// Admin view of the renewal offer of one pass (the tile chips).
class PassRenewalOfferSummary extends Equatable {
  const PassRenewalOfferSummary({
    required this.monthlyPassId,
    required this.status,
    this.remindersSent = 0,
    this.lastReminderAt,
  });

  final int monthlyPassId;

  /// `open`, `paid`, `expired` or `cancelled`.
  final String status;
  final int remindersSent;
  final DateTime? lastReminderAt;

  bool get isOpen => status == 'open';
  bool get isPaid => status == 'paid';

  factory PassRenewalOfferSummary.fromJson(Map<String, dynamic> json) =>
      PassRenewalOfferSummary(
        monthlyPassId: (json['monthly_pass_id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'open',
        remindersSent: (json['reminders_sent'] as num?)?.toInt() ?? 0,
        lastReminderAt: DateTime.tryParse(
          json['last_reminder_at'] as String? ?? '',
        ),
      );

  @override
  List<Object?> get props => [
    monthlyPassId,
    status,
    remindersSent,
    lastReminderAt,
  ];
}
