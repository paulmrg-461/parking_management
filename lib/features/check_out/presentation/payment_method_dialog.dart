import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_input.dart';
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
    this.cardType,
    this.cashReceived,
  });

  final PaymentMethod method;
  final int discountAmount;
  final String? discountReason;
  final bool lostTicket;
  final String? lostTicketReason;

  /// Card type when the customer pays with card.
  final CardType? cardType;

  /// Cash handed over (null = exact/unknown); only used to show the change.
  final int? cashReceived;
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

/// Inputs that can carry an inline validation message.
enum _Field { cash, discountAmount, discountReason, lostReason }

class _CheckoutDialogState extends State<_CheckoutDialog> {
  /// How many bill shortcuts to offer above the cash field.
  static const _cashShortcuts = 3;

  late PaymentMethod _selected = widget.initialMethod;
  CardType _cardType = CardType.debit;
  final _cashController = TextEditingController();
  final _discountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _lostReasonController = TextEditingController();
  bool _lostTicket = false;
  final Map<_Field, String> _errors = {};

  @override
  void dispose() {
    _cashController.dispose();
    _discountController.dispose();
    _reasonController.dispose();
    _lostReasonController.dispose();
    super.dispose();
  }

  int get _discount => widget.canDiscount
      ? Money.parse(_discountController.text.trim()) ?? 0
      : 0;

  /// Total still due after the admin discount. A lost ticket charges the
  /// server's `lost_ticket_amount` (older servers: the regular fare).
  int? get _due {
    final preview = widget.preview;
    final amount = _lostTicket
        ? preview?.lostTicketAmount ?? preview?.amount
        : preview?.amount;
    if (amount == null) {
      return null;
    }
    return (amount - _discount).clamp(0, amount);
  }

  /// A lost ticket is always charged: a monthly pass cannot cover it
  /// (`LostTicketPassMethodError`), so the method falls back to cash.
  void _setLostTicket(bool? value) {
    _lostTicket = value ?? false;
    if (_lostTicket && _selected == PaymentMethod.monthlyPass) {
      _selected = PaymentMethod.cash;
    }
  }

  int? get _cashReceived {
    final value = Money.parse(_cashController.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  /// The smallest bills that cover [due], for one-tap "paid with" input.
  List<int> _billsCovering(int due) => [
    for (final bill in Money.currency.denominations.reversed)
      if (bill > due) bill,
  ].take(_cashShortcuts).toList();

  void _setCash(int amount) {
    _cashController.text = Money.input(amount);
    setState(() => _errors.remove(_Field.cash));
  }

  void _clearError(_Field field) => setState(() => _errors.remove(field));

  /// Validates every input and returns the message per offending field.
  Map<_Field, String> _validate() {
    final l10n = context.l10n;
    final received = _cashReceived;
    final due = _due;
    return {
      if (_discount < 0) _Field.discountAmount: l10n.invalidAmount,
      if (_discount > 0 && _reasonController.text.trim().isEmpty)
        _Field.discountReason: l10n.discountReasonRequired,
      if (_lostTicket && _lostReasonController.text.trim().isEmpty)
        _Field.lostReason: l10n.lostTicketReasonRequired,
      if (_selected == PaymentMethod.cash &&
          received != null &&
          due != null &&
          received < due)
        _Field.cash: l10n.checkoutCashShortError,
    };
  }

  void _confirm() {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      return;
    }
    Navigator.of(context).pop(_choice());
  }

  CheckoutChoice _choice() {
    final discount = _discount;
    return CheckoutChoice(
      method: _selected,
      discountAmount: discount,
      discountReason: discount > 0 ? _reasonController.text.trim() : null,
      lostTicket: _lostTicket,
      lostTicketReason: _lostTicket ? _lostReasonController.text.trim() : null,
      cardType: _selected == PaymentMethod.card ? _cardType : null,
      cashReceived: _selected == PaymentMethod.cash ? _cashReceived : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = _due;
    return AlertDialog(
      title: Text(l10n.checkOutSettlement),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.checkOutConfirm(widget.plate)),
              const SizedBox(height: Space.sm),
              if (widget.preview case final preview?)
                FareBreakdownView(preview: preview)
              else
                Text(
                  l10n.slotEstimateUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (due != null && _discount > 0) _buildDueRow(context, due),
              const SizedBox(height: Space.sm),
              ..._buildMethodPicker(context),
              if (_selected == PaymentMethod.cash && due != null) ...[
                const SizedBox(height: Space.sm),
                _buildCashBox(context, due),
              ],
              const SizedBox(height: Space.sm),
              CheckboxListTile(
                value: _lostTicket,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() {
                  _setLostTicket(value);
                  _errors.remove(_Field.lostReason);
                }),
                title: Text(l10n.lostTicket),
                subtitle: Text(l10n.lostTicketHint),
              ),
              if (_lostTicket)
                TextFormField(
                  controller: _lostReasonController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.lostTicketReason,
                    errorText: _errors[_Field.lostReason],
                  ),
                  onChanged: (_) => _clearError(_Field.lostReason),
                ),
              if (widget.canDiscount) ..._buildDiscountFields(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton.icon(
          key: const Key('checkout_confirm'),
          onPressed: _confirm,
          icon: const Icon(Icons.check),
          label: Text(
            due == null
                ? l10n.actionConfirm
                : l10n.checkoutChargeAmount(Money.format(due)),
          ),
        ),
      ],
    );
  }

  /// The discounted total, so the operator charges what is really owed.
  Widget _buildDueRow(BuildContext context, int due) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        key: const Key('checkout_due_after_discount'),
        children: [
          Expanded(
            child: Text(
              context.l10n.fareTotal,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            Money.format(due),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMethodPicker(BuildContext context) {
    final l10n = context.l10n;
    return [
      Text(
        l10n.paymentMethodTitle,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: Space.xs),
      // Four methods do not fit in a segmented control on a phone: the
      // labels squeeze and overflow. Chips wrap to two rows instead.
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final method in PaymentMethod.values)
            ChoiceChip(
              selected: _selected == method,
              showCheckmark: false,
              avatar: Icon(method.icon, size: 18),
              label: Text(method.label(l10n)),
              // The server rejects a lost ticket paid by pass.
              onSelected: _lostTicket && method == PaymentMethod.monthlyPass
                  ? null
                  : (_) => setState(() {
                      _selected = method;
                      _errors.remove(_Field.cash);
                    }),
            ),
        ],
      ),
      if (_selected == PaymentMethod.card) ...[
        const SizedBox(height: Space.sm),
        Text(
          l10n.checkoutCardType,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: Space.xs),
        SegmentedButton<CardType>(
          showSelectedIcon: false,
          segments: [
            for (final kind in CardType.values)
              ButtonSegment(
                value: kind,
                icon: Icon(kind.icon),
                label: Text(kind.label(l10n)),
              ),
          ],
          selected: {_cardType},
          onSelectionChanged: (selection) =>
              setState(() => _cardType = selection.first),
        ),
      ],
    ];
  }

  Widget _buildCashBox(BuildContext context, int due) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              ActionChip(
                key: const Key('checkout_cash_exact'),
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(l10n.checkoutCashExact),
                onPressed: () => _setCash(due),
              ),
              for (final bill in _billsCovering(due))
                ActionChip(
                  label: Text(Money.format(bill)),
                  onPressed: () => _setCash(bill),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('checkout_cash_received'),
            controller: _cashController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: moneyInputFormatters(),
            decoration: InputDecoration(
              labelText: l10n.checkoutCashReceived,
              prefixText: '${Money.currency.symbol} ',
              filled: true,
              fillColor: scheme.surface,
              errorText: _errors[_Field.cash],
            ),
            onChanged: (_) => _clearError(_Field.cash),
            onSubmitted: (_) => _confirm(),
          ),
          if (_cashReceived case final received?)
            _buildChangeRow(context, received: received, due: due),
        ],
      ),
    );
  }

  Widget _buildChangeRow(
    BuildContext context, {
    required int received,
    required int due,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final covered = received >= due;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              covered ? l10n.checkoutCashChange : l10n.checkoutCashShort,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            Money.format((received - due).abs()),
            style: theme.textTheme.titleLarge?.copyWith(
              color: covered
                  ? StatusColors.of(context).success
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDiscountFields(BuildContext context) {
    final l10n = context.l10n;
    return [
      const SizedBox(height: Space.sm),
      TextFormField(
        key: const Key('checkout_discount_amount'),
        controller: _discountController,
        keyboardType: TextInputType.number,
        inputFormatters: moneyInputFormatters(),
        decoration: InputDecoration(
          labelText: l10n.discountAmount,
          errorText: _errors[_Field.discountAmount],
        ),
        // The total due and the change follow the discount as it is typed.
        onChanged: (_) => setState(() {
          _errors
            ..remove(_Field.discountAmount)
            ..remove(_Field.cash);
        }),
      ),
      const SizedBox(height: Space.sm),
      TextFormField(
        key: const Key('checkout_discount_reason'),
        controller: _reasonController,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.discountReason,
          errorText: _errors[_Field.discountReason],
        ),
        onChanged: (_) => _clearError(_Field.discountReason),
      ),
    ];
  }
}
