import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

enum PaymentMethod { cash, card, transfer, monthlyPass, exempt }

extension PaymentMethodX on PaymentMethod {
  String get wire => switch (this) {
    PaymentMethod.cash => 'cash',
    PaymentMethod.card => 'card',
    PaymentMethod.transfer => 'transfer',
    PaymentMethod.monthlyPass => 'monthly_pass',
    PaymentMethod.exempt => 'exempt',
  };

  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.paymentCash,
    PaymentMethod.card => l10n.paymentCard,
    PaymentMethod.transfer => l10n.paymentTransfer,
    PaymentMethod.monthlyPass => l10n.paymentMonthlyPass,
    PaymentMethod.exempt => l10n.paymentExempt,
  };

  IconData get icon => switch (this) {
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.card => Icons.credit_card,
    PaymentMethod.transfer => Icons.account_balance_outlined,
    PaymentMethod.monthlyPass => Icons.card_membership,
    PaymentMethod.exempt => Icons.remove_circle_outline,
  };
}

PaymentMethod paymentMethodFromWire(String? value) => switch (value) {
  'card' => PaymentMethod.card,
  'transfer' => PaymentMethod.transfer,
  'monthly_pass' => PaymentMethod.monthlyPass,
  'exempt' => PaymentMethod.exempt,
  _ => PaymentMethod.cash,
};

String paymentMethodLabel(AppLocalizations l10n, String? wire) =>
    wire == null || wire == 'unknown'
    ? l10n.paymentUnknown
    : paymentMethodFromWire(wire).label(l10n);
