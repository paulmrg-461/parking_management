import 'package:equatable/equatable.dart';

/// Intent state as the gateway reports it (`payment_intents.status`).
enum PaymentStatus { pending, approved, declined, voided, error, expired }

extension PaymentStatusX on PaymentStatus {
  /// Approved or voided: polling can stop (money decided).
  bool get isFinal =>
      this == PaymentStatus.approved || this == PaymentStatus.voided;

  bool get isApproved => this == PaymentStatus.approved;

  static PaymentStatus? fromWire(String? value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'approved' => PaymentStatus.approved,
    'declined' => PaymentStatus.declined,
    'voided' => PaymentStatus.voided,
    'error' => PaymentStatus.error,
    'expired' => PaymentStatus.expired,
    _ => null,
  };
}

/// Public status of an intent, keyed by reference + plate.
class PaymentIntentStatus extends Equatable {
  const PaymentIntentStatus({
    required this.status,
    required this.amount,
    required this.sessionId,
    this.paidTotal = 0,
    this.graceUntil,
  });

  final PaymentStatus status;
  final int amount;
  final int sessionId;

  /// Everything paid online for the session so far (a voided payment is
  /// subtracted server-side).
  final int paidTotal;
  final DateTime? graceUntil;

  factory PaymentIntentStatus.fromJson(Map<String, dynamic> json) =>
      PaymentIntentStatus(
        status:
            PaymentStatusX.fromWire(json['status'] as String?) ??
            PaymentStatus.pending,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
        paidTotal: (json['paid_total'] as num?)?.toInt() ?? 0,
        graceUntil: DateTime.tryParse(json['grace_until'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [status, amount, sessionId, paidTotal, graceUntil];
}
