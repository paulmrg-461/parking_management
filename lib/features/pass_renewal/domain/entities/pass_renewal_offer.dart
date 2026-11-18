import 'package:equatable/equatable.dart';

/// State of a renewal offer as the public page reads it.
enum PassRenewalStatus { open, paid, expired, cancelled }

extension PassRenewalStatusX on PassRenewalStatus {
  static PassRenewalStatus? fromWire(String? value) => switch (value) {
    'open' => PassRenewalStatus.open,
    'paid' => PassRenewalStatus.paid,
    'expired' => PassRenewalStatus.expired,
    'cancelled' => PassRenewalStatus.cancelled,
    _ => null,
  };

  bool get isOpen => this == PassRenewalStatus.open;
  bool get isPaid => this == PassRenewalStatus.paid;
}

/// One token-keyed renewal offer: the planned period, the amount and only the
/// masked plate (the link is the access key).
class PassRenewalOffer extends Equatable {
  const PassRenewalOffer({
    required this.status,
    required this.lotName,
    required this.plateMasked,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.currency,
    required this.expiresAt,
    this.paymentLinksEnabled = false,
    this.renewalPeriodStart,
    this.renewalPeriodEnd,
  });

  final PassRenewalStatus status;
  final String lotName;
  final String plateMasked;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int amount;
  final String currency;
  final DateTime expiresAt;

  /// The lot still allows paying this link (online payments + keys).
  final bool paymentLinksEnabled;

  /// Filled once the offer is paid: the pass that was actually created.
  final DateTime? renewalPeriodStart;
  final DateTime? renewalPeriodEnd;

  factory PassRenewalOffer.fromJson(Map<String, dynamic> json) =>
      PassRenewalOffer(
        status:
            PassRenewalStatusX.fromWire(json['status'] as String?) ??
            PassRenewalStatus.open,
        lotName: json['lot_name'] as String? ?? '',
        plateMasked: json['plate_masked'] as String? ?? '',
        periodStart: _date(json['period_start']) ?? DateTime.now(),
        periodEnd: _date(json['period_end']) ?? DateTime.now(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'COP',
        expiresAt: _date(json['expires_at']) ?? DateTime.now(),
        paymentLinksEnabled: json['payment_links_enabled'] as bool? ?? false,
        renewalPeriodStart: _date(json['renewal_period_start']),
        renewalPeriodEnd: _date(json['renewal_period_end']),
      );

  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  @override
  List<Object?> get props => [
    status,
    lotName,
    plateMasked,
    periodStart,
    periodEnd,
    amount,
    currency,
    expiresAt,
    paymentLinksEnabled,
    renewalPeriodStart,
    renewalPeriodEnd,
  ];
}
