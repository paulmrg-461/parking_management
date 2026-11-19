import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_input.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../domain/entities/pricing_rule.dart';

Future<PricingRuleDraft?> showPricingRuleDialog(
  BuildContext context, {
  PricingRule? rule,
}) => showDialog<PricingRuleDraft>(
  context: context,
  builder: (_) => _PricingRuleDialog(rule: rule),
);

class _PricingRuleDialog extends StatefulWidget {
  const _PricingRuleDialog({this.rule});

  final PricingRule? rule;

  @override
  State<_PricingRuleDialog> createState() => _PricingRuleDialogState();
}

const _groups = [null, 'car', 'moto', 'heavy'];

class _PricingRuleDialogState extends State<_PricingRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.rule?.name ?? '',
  );
  late final TextEditingController _priority = TextEditingController(
    text: '${widget.rule?.priority ?? 100}',
  );
  late final TextEditingController _min = TextEditingController(
    text: widget.rule?.minOccupancyPct?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.rule?.maxOccupancyPct?.toString() ?? '',
  );
  late final TextEditingController _multiplier = TextEditingController(
    text: '${(widget.rule?.multiplierBps ?? 10000) ~/ 100}',
  );
  late final TextEditingController _surcharge = TextEditingController(
    text: widget.rule == null ? '' : Money.input(widget.rule!.surchargeAmount),
  );
  late String? _group = widget.rule?.group;
  late Set<int> _days = widget.rule?.weekdaySet ?? {};
  late TimeOfDay? _from = _time(widget.rule?.fromMinute);
  late TimeOfDay? _to = _time(widget.rule?.toMinute);
  late bool _active = widget.rule?.active ?? true;

  static TimeOfDay? _time(int? minutes) => minutes == null
      ? null
      : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  @override
  void dispose() {
    _name.dispose();
    _priority.dispose();
    _min.dispose();
    _max.dispose();
    _multiplier.dispose();
    _surcharge.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool from}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (from ? _from : _to) ?? TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    int? minutes(TimeOfDay? time) =>
        time == null ? null : time.hour * 60 + time.minute;
    final weekdays = _days.isEmpty
        ? null
        : _days.fold<int>(0, (mask, day) => mask | (1 << (day - 1)));
    Navigator.of(context).pop(
      PricingRuleDraft(
        id: widget.rule?.id,
        name: _name.text.trim(),
        priority: int.tryParse(_priority.text.trim()) ?? 100,
        group: _group,
        minOccupancyPct: int.tryParse(_min.text.trim()),
        maxOccupancyPct: int.tryParse(_max.text.trim()),
        weekdays: weekdays,
        fromMinute: minutes(_from),
        toMinute: minutes(_to),
        multiplierBps:
            (int.tryParse(_multiplier.text.trim()) ?? 100) * 100,
        surchargeAmount: Money.parse(_surcharge.text.trim()) ?? 0,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('pricing_rule_dialog'),
      scrollable: true,
      title: DialogHeader(
        icon: Icons.trending_up_outlined,
        title: widget.rule == null ? l10n.pricingAddRule : l10n.pricingEditRule,
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('pricing_rule_name'),
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(labelText: l10n.pricingRuleName),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
              ),
              TextFormField(
                key: const Key('pricing_rule_priority'),
                controller: _priority,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.pricingRulePriority,
                ),
              ),
              const SizedBox(height: Space.sm),
              DropdownButtonFormField<String?>(
                key: const Key('pricing_rule_group'),
                isExpanded: true,
                initialValue: _group,
                decoration: InputDecoration(labelText: l10n.pricingRuleGroup),
                items: [
                  for (final group in _groups)
                    DropdownMenuItem(
                      value: group,
                      child: Text(
                        group == null
                            ? l10n.pricingRuleGroupAll
                            : group,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _group = value),
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('pricing_rule_min'),
                      controller: _min,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.pricingRuleOccupancyFrom,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: TextFormField(
                      key: const Key('pricing_rule_max'),
                      controller: _max,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.pricingRuleOccupancyTo,
                      ),
                      validator: (value) {
                        final min = int.tryParse(_min.text.trim());
                        final max = int.tryParse((value ?? '').trim());
                        return min != null && max != null && min > max
                            ? l10n.errorInvalidPricingRule
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(l10n.pricingRuleWeekdays),
              Wrap(
                spacing: Space.xs,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text('$day'),
                      selected: _days.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('pricing_rule_from'),
                      onPressed: () => _pickTime(from: true),
                      child: Text(
                        _from == null
                            ? l10n.pricingRuleFromTime
                            : _from!.format(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('pricing_rule_to'),
                      onPressed: () => _pickTime(from: false),
                      child: Text(
                        _to == null
                            ? l10n.pricingRuleToTime
                            : _to!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('pricing_rule_multiplier'),
                      controller: _multiplier,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.pricingRuleMultiplier,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: TextFormField(
                      key: const Key('pricing_rule_surcharge'),
                      controller: _surcharge,
                      keyboardType: TextInputType.number,
                      inputFormatters: moneyInputFormatters(),
                      decoration: InputDecoration(
                        labelText: l10n.pricingRuleSurcharge,
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                key: const Key('pricing_rule_active'),
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: Text(l10n.pricingRuleActive),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('pricing_rule_save'),
          onPressed: _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
