import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/payment_method.dart';
import '../domain/entities/check_out_preview.dart';
import 'widgets/fare_breakdown_view.dart';

class CheckoutChoice {
  const CheckoutChoice({
    required this.method,
    this.discountAmount = 0,
    this.discountReason,
    this.lostTicket = false,
    this.lostTicketReason,
  });

  final PaymentMethod method;
  final int discountAmount;
  final String? discountReason;
  final bool lostTicket;
  final String? lostTicketReason;
}

/// Asks how the customer paid (and, for admins, an optional audited
/// discount) before closing a session.
Future<CheckoutChoice?> showCheckoutDialog(
  BuildContext context, {
  required String plate,
  required bool canDiscount,
  CheckOutPreview? preview,
  PaymentMethod initialMethod = PaymentMethod.cash,
}) => showDialog<CheckoutChoice>(
  context: context,
  builder: (_) => _CheckoutDialog(
    plate: plate,
    canDiscount: canDiscount,
    preview: preview,
    initialMethod: initialMethod,
  ),
);

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.plate,
    required this.canDiscount,
    this.preview,
    this.initialMethod = PaymentMethod.cash,
  });

  final String plate;
  final bool canDiscount;
  final CheckOutPreview? preview;
  final PaymentMethod initialMethod;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late PaymentMethod _selected = widget.initialMethod;
  final _discountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _lostReasonController = TextEditingController();
  bool _lostTicket = false;
  String? _error;

  @override
  void dispose() {
    _discountController.dispose();
    _reasonController.dispose();
    _lostReasonController.dispose();
    super.dispose();
  }

  void _confirm() {
    final discount = widget.canDiscount
        ? int.tryParse(_discountController.text.trim()) ?? 0
        : 0;
    final reason = _reasonController.text.trim();
    final lostReason = _lostReasonController.text.trim();
    if (discount < 0) {
      setState(() => _error = context.l10n.invalidAmount);
      return;
    }
    if (discount > 0 && reason.isEmpty) {
      setState(() => _error = context.l10n.discountReasonRequired);
      return;
    }
    if (_lostTicket && lostReason.isEmpty) {
      setState(() => _error = context.l10n.lostTicketReasonRequired);
      return;
    }
    Navigator.of(context).pop(
      CheckoutChoice(
        method: _selected,
        discountAmount: discount,
        discountReason: discount > 0 ? reason : null,
        lostTicket: _lostTicket,
        lostTicketReason: _lostTicket ? lostReason : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.checkOutSettlement),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.checkOutConfirm(widget.plate)),
            const SizedBox(height: 8),
            if (widget.preview case final preview?)
              FareBreakdownView(preview: preview)
            else
              Text(
                l10n.slotEstimateUnavailable,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              l10n.paymentMethodTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final method in PaymentMethod.values)
              RadioListTile<PaymentMethod>(
                value: method,
                groupValue: _selected,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selected = value);
                  }
                },
                title: Text(method.label(l10n)),
                secondary: Icon(method.icon),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _lostTicket,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  setState(() => _lostTicket = value ?? false),
              title: Text(l10n.lostTicket),
              subtitle: Text(l10n.lostTicketHint),
            ),
            if (_lostTicket)
              TextFormField(
                controller: _lostReasonController,
                decoration: InputDecoration(
                  labelText: l10n.lostTicketReason,
                ),
              ),
            if (widget.canDiscount) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.discountAmount,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.discountReason,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(l10n.actionConfirm),
        ),
      ],
    );
  }
}
