import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/payment_method.dart';

/// Asks how the customer paid before closing a session.
Future<PaymentMethod?> showPaymentMethodDialog(
  BuildContext context, {
  required String plate,
}) => showDialog<PaymentMethod>(
  context: context,
  builder: (_) => _PaymentMethodDialog(plate: plate),
);

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog({required this.plate});

  final String plate;

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  PaymentMethod _selected = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.paymentMethodTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.checkOutConfirm(widget.plate)),
          const SizedBox(height: 8),
          for (final method in PaymentMethod.values)
            RadioListTile<PaymentMethod>(
              value: method,
              groupValue: _selected,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selected = value);
                }
              },
              title: Text(method.label(context.l10n)),
              secondary: Icon(method.icon),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(context.l10n.actionConfirm),
        ),
      ],
    );
  }
}
