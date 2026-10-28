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

enum CardType { debit, credit }

extension CardTypeX on CardType {
  String get wire => switch (this) {
    CardType.debit => 'debit',
    CardType.credit => 'credit',
  };

  String label(AppLocalizations l10n) => switch (this) {
    CardType.debit => l10n.paymentCardDebit,
    CardType.credit => l10n.paymentCardCredit,
  };

  IconData get icon => switch (this) {
    CardType.debit => Icons.savings_outlined,
    CardType.credit => Icons.credit_score_outlined,
  };
}

CardType? cardTypeFromWire(String? value) => switch (value) {
  'debit' => CardType.debit,
  'credit' => CardType.credit,
  _ => null,
};

PaymentMethod paymentMethodFromWire(String? value) => switch (value) {
  'card' => PaymentMethod.card,
  'transfer' => PaymentMethod.transfer,
  'monthly_pass' => PaymentMethod.monthlyPass,
  'exempt' => PaymentMethod.exempt,
  _ => PaymentMethod.cash,
};

String paymentMethodLabel(
  AppLocalizations l10n,
  String? wire, {
  String? cardType,
}) {
  if (wire == null || wire == 'unknown') {
    return l10n.paymentUnknown;
  }
  final method = paymentMethodFromWire(wire);
  final kind = cardTypeFromWire(cardType);
  return method == PaymentMethod.card && kind != null
      ? '${method.label(l10n)} · ${kind.label(l10n)}'
      : method.label(l10n);
}
