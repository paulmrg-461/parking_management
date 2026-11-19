import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_input.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/entities/loyalty_settings.dart';

/// The program form: threshold, reward value, anti-abuse floors and mode.
class LoyaltySettingsForm extends StatefulWidget {
  const LoyaltySettingsForm({
    super.key,
    required this.settings,
    required this.onSave,
    this.busy = false,
  });

  final LoyaltySettings settings;
  final ValueChanged<LoyaltySettings> onSave;
  final bool busy;

  @override
  State<LoyaltySettingsForm> createState() => _LoyaltySettingsFormState();
}

class _LoyaltySettingsFormState extends State<LoyaltySettingsForm> {
  late bool _enabled = widget.settings.enabled;
  late LoyaltyRewardKind _kind = widget.settings.rewardKind;
  late LoyaltyRedeemMode _mode = widget.settings.redeemMode;
  late bool _stack = widget.settings.stackWithMerchant;
  late final _visits = TextEditingController(
    text: '${widget.settings.visitsRequired}',
  );
  late final _max = TextEditingController(
    text: widget.settings.rewardMaxAmount == null
        ? ''
        : Money.input(widget.settings.rewardMaxAmount!),
  );
  late final _fixed = TextEditingController(
    text: Money.input(widget.settings.rewardFixedAmount),
  );
  late final _minAmount = TextEditingController(
    text: Money.input(widget.settings.minAmount),
  );
  late final _minMinutes = TextEditingController(
    text: '${widget.settings.minMinutes}',
  );
  late final _validDays = TextEditingController(
    text: '${widget.settings.rewardValidDays}',
  );
  String? _error;

  @override
  void dispose() {
    _visits.dispose();
    _max.dispose();
    _fixed.dispose();
    _minAmount.dispose();
    _minMinutes.dispose();
    _validDays.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final visits = int.tryParse(_visits.text.trim());
    final minutes = int.tryParse(_minMinutes.text.trim());
    final days = int.tryParse(_validDays.text.trim());
    final fixed = Money.parse(_fixed.text) ?? -1;
    final minAmount = Money.parse(_minAmount.text) ?? -1;
    final max = _max.text.trim().isEmpty ? null : Money.parse(_max.text);
    if (visits == null ||
        visits < 2 ||
        visits > 50 ||
        minutes == null ||
        minutes < 0 ||
        minutes > 1440 ||
        days == null ||
        days < 7 ||
        days > 730 ||
        fixed < 0 ||
        minAmount < 0 ||
        (_kind == LoyaltyRewardKind.fixedAmount && fixed <= 0) ||
        (max != null && max <= 0)) {
      setState(() => _error = l10n.errorLoyaltySettings);
      return;
    }
    setState(() => _error = null);
    widget.onSave(
      LoyaltySettings(
        enabled: _enabled,
        visitsRequired: visits,
        rewardKind: _kind,
        rewardMaxAmount: max,
        rewardFixedAmount: fixed,
        minAmount: minAmount,
        minMinutes: minutes,
        redeemMode: _mode,
        stackWithMerchant: _stack,
        rewardValidDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const Key('loyalty_settings_form'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.loyalty_outlined,
              title: l10n.loyaltyTabProgram,
            ),
            SwitchListTile(
              key: const Key('loyalty_enabled'),
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: Text(l10n.loyaltyEnabled),
            ),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                _numberField(
                  key: const Key('loyalty_visits'),
                  controller: _visits,
                  label: l10n.loyaltyVisitsRequired,
                ),
                _numberField(
                  key: const Key('loyalty_valid_days'),
                  controller: _validDays,
                  label: l10n.loyaltyValidDays,
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            DropdownButtonFormField<LoyaltyRewardKind>(
              key: const Key('loyalty_kind'),
              isExpanded: true,
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.loyaltyRewardKind),
              items: [
                DropdownMenuItem(
                  value: LoyaltyRewardKind.freeStay,
                  child: Text(l10n.loyaltyKindFreeStay),
                ),
                DropdownMenuItem(
                  value: LoyaltyRewardKind.fixedAmount,
                  child: Text(l10n.loyaltyKindFixed),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: Space.sm),
            if (_kind == LoyaltyRewardKind.freeStay)
              TextFormField(
                key: const Key('loyalty_max'),
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters(),
                decoration: InputDecoration(
                  labelText: l10n.loyaltyRewardMax,
                ),
              )
            else
              TextFormField(
                key: const Key('loyalty_fixed'),
                controller: _fixed,
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters(),
                decoration: InputDecoration(
                  labelText: l10n.loyaltyRewardFixed,
                ),
              ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    key: const Key('loyalty_min_amount'),
                    controller: _minAmount,
                    keyboardType: TextInputType.number,
                    inputFormatters: moneyInputFormatters(),
                    decoration: InputDecoration(
                      labelText: l10n.loyaltyMinAmount,
                    ),
                  ),
                ),
                _numberField(
                  key: const Key('loyalty_min_minutes'),
                  controller: _minMinutes,
                  label: l10n.loyaltyMinMinutes,
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            DropdownButtonFormField<LoyaltyRedeemMode>(
              key: const Key('loyalty_mode'),
              isExpanded: true,
              initialValue: _mode,
              decoration: InputDecoration(labelText: l10n.loyaltyRedeemMode),
              items: [
                DropdownMenuItem(
                  value: LoyaltyRedeemMode.auto,
                  child: Text(l10n.loyaltyModeAuto),
                ),
                DropdownMenuItem(
                  value: LoyaltyRedeemMode.operator,
                  child: Text(l10n.loyaltyModeOperator),
                ),
              ],
              onChanged: (value) => setState(() => _mode = value ?? _mode),
            ),
            SwitchListTile(
              key: const Key('loyalty_stack'),
              contentPadding: EdgeInsets.zero,
              value: _stack,
              onChanged: (value) => setState(() => _stack = value),
              title: Text(l10n.loyaltyStackMerchant),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('loyalty_save'),
                onPressed: widget.busy ? null : _save,
                child: Text(l10n.loyaltySave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) => SizedBox(
    width: 170,
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    ),
  );
}
