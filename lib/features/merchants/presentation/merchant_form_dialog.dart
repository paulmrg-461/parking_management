import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_input.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../domain/entities/merchant.dart';

/// Create/edit one agreement. Returns the draft (the cubit saves it).
Future<MerchantDraft?> showMerchantFormDialog(
  BuildContext context, {
  Merchant? merchant,
}) => showDialog<MerchantDraft>(
  context: context,
  builder: (_) => _MerchantFormDialog(merchant: merchant),
);

class _MerchantFormDialog extends StatefulWidget {
  const _MerchantFormDialog({this.merchant});

  final Merchant? merchant;

  @override
  State<_MerchantFormDialog> createState() => _MerchantFormDialogState();
}

class _MerchantFormDialogState extends State<_MerchantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _maxAmount;
  late final TextEditingController _dailyCap;
  late final TextEditingController _monthlyCap;
  late MerchantBenefitKind _kind;
  late MerchantBillingMode _billing;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final merchant = widget.merchant;
    _name = TextEditingController(text: merchant?.name ?? '');
    _kind = merchant?.kind ?? MerchantBenefitKind.percentage;
    _value = TextEditingController(
      text: merchant == null ? '' : _valueText(merchant),
    );
    _maxAmount = TextEditingController(
      text: merchant?.maxAmount == null
          ? ''
          : Money.input(merchant!.maxAmount!),
    );
    _dailyCap = TextEditingController(text: merchant?.dailyCap?.toString() ?? '');
    _monthlyCap = TextEditingController(
      text: merchant?.monthlyCap?.toString() ?? '',
    );
    _billing = merchant?.billingMode ?? MerchantBillingMode.merchantPaid;
    _active = merchant?.active ?? true;
  }

  static String _valueText(Merchant merchant) =>
      merchant.kind == MerchantBenefitKind.fixedAmount
      ? Money.input(merchant.value)
      : merchant.value.toString();

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _maxAmount.dispose();
    _dailyCap.dispose();
    _monthlyCap.dispose();
    super.dispose();
  }

  int? get _amount => Money.parse(_maxAmount.text.trim());

  String? _validateValue(String? raw) {
    final text = (raw ?? '').trim();
    final number = _kind == MerchantBenefitKind.fixedAmount
        ? Money.parse(text)
        : int.tryParse(text);
    if (number == null) {
      return context.l10n.invalidAmount;
    }
    return switch (_kind) {
      MerchantBenefitKind.freeMinutes =>
        number >= 1 && number <= 1440 ? null : context.l10n.invalidAmount,
      MerchantBenefitKind.percentage =>
        number >= 1 && number <= 100 ? null : context.l10n.invalidAmount,
      MerchantBenefitKind.fixedAmount =>
        number >= 1 ? null : context.l10n.invalidAmount,
    };
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final value = _kind == MerchantBenefitKind.fixedAmount
        ? Money.parse(_value.text.trim()) ?? 0
        : int.tryParse(_value.text.trim()) ?? 0;
    Navigator.of(context).pop(
      MerchantDraft(
        id: widget.merchant?.id,
        name: _name.text.trim(),
        kind: _kind,
        value: value,
        maxAmount: _amount,
        billingMode: _billing,
        dailyCap: int.tryParse(_dailyCap.text.trim()),
        monthlyCap: int.tryParse(_monthlyCap.text.trim()),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: DialogHeader(
        icon: Icons.storefront_outlined,
        title: widget.merchant == null ? l10n.merchantsAdd : l10n.merchantFormName,
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('merchant_name'),
                  controller: _name,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: l10n.merchantFormName),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return text.length >= 2 ? null : l10n.fieldRequired;
                  },
                ),
                const SizedBox(height: Space.sm),
                DropdownButtonFormField<MerchantBenefitKind>(
                  key: const Key('merchant_kind'),
                  isExpanded: true,
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: l10n.merchantFormKind),
                  items: [
                    DropdownMenuItem(
                      value: MerchantBenefitKind.freeMinutes,
                      child: Text(l10n.merchantKindFreeMinutes),
                    ),
                    DropdownMenuItem(
                      value: MerchantBenefitKind.percentage,
                      child: Text(l10n.merchantKindPercentage),
                    ),
                    DropdownMenuItem(
                      value: MerchantBenefitKind.fixedAmount,
                      child: Text(l10n.merchantKindFixedAmount),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    if (value != null) {
                      _kind = value;
                      _value.clear();
                    }
                  }),
                ),
                const SizedBox(height: Space.sm),
                TextFormField(
                  key: const Key('merchant_value'),
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: _kind == MerchantBenefitKind.fixedAmount
                      ? moneyInputFormatters()
                      : [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: switch (_kind) {
                      MerchantBenefitKind.freeMinutes =>
                        l10n.merchantFormValueMinutes,
                      MerchantBenefitKind.percentage =>
                        l10n.merchantFormValuePercent,
                      MerchantBenefitKind.fixedAmount =>
                        l10n.merchantFormValueAmount,
                    },
                  ),
                  validator: _validateValue,
                ),
                const SizedBox(height: Space.sm),
                TextFormField(
                  key: const Key('merchant_max_amount'),
                  controller: _maxAmount,
                  keyboardType: TextInputType.number,
                  inputFormatters: moneyInputFormatters(),
                  decoration: InputDecoration(
                    labelText: l10n.merchantFormMaxAmount,
                  ),
                ),
                const SizedBox(height: Space.sm),
                DropdownButtonFormField<MerchantBillingMode>(
                  isExpanded: true,
                  initialValue: _billing,
                  decoration: InputDecoration(
                    labelText: l10n.merchantFormBilling,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: MerchantBillingMode.merchantPaid,
                      child: Text(l10n.merchantBillingMerchantPaid),
                    ),
                    DropdownMenuItem(
                      value: MerchantBillingMode.courtesy,
                      child: Text(l10n.merchantBillingCourtesy),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    if (value != null) {
                      _billing = value;
                    }
                  }),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('merchant_daily_cap'),
                        controller: _dailyCap,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: l10n.merchantFormDailyCap,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: TextFormField(
                        key: const Key('merchant_monthly_cap'),
                        controller: _monthlyCap,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: l10n.merchantFormMonthlyCap,
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  key: const Key('merchant_active'),
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: Text(l10n.merchantFormActive),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('merchant_save'),
          onPressed: _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
