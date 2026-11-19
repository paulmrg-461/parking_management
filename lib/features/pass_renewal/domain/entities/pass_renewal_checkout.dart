import 'package:equatable/equatable.dart';

/// Gateway checkout for a renewal offer.
class PassRenewalCheckout extends Equatable {
  const PassRenewalCheckout({
    required this.checkoutUrl,
    required this.reference,
    required this.expiresAt,
  });

  final String checkoutUrl;
  final String reference;
  final DateTime expiresAt;

  factory PassRenewalCheckout.fromJson(Map<String, dynamic> json) =>
      PassRenewalCheckout(
        checkoutUrl: json['checkout_url'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [checkoutUrl, reference, expiresAt];
}
