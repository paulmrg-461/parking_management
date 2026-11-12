import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/dialog_header.dart';
import '../../application/anomalies_cubit.dart';
import '../../domain/entities/anomaly_settings.dart';
import '../../domain/entities/cash_anomaly.dart';
import '../anomalies_page.dart';

/// The per-lot thresholds (admin only; the server enforces it too).
class AnomalySettingsSheet extends StatefulWidget {
  const AnomalySettingsSheet({super.key});

  @override
  State<AnomalySettingsSheet> createState() => _AnomalySettingsSheetState();
}

class _AnomalySettingsSheetState extends State<AnomalySettingsSheet> {
  final Map<String, TextEditingController> _fields = {};
  AnomalySettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await context.read<AnomaliesCubit>().loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.failure(failure);
        });
      }
    }
  }

  TextEditingController _controller(String key, int value) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: '$value'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = _settings;
    return Padding(
      padding: EdgeInsets.only(
        left: Space.md,
        right: Space.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Space.md,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          : settings == null
          ? Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Text(_error ?? l10n.anomaliesEmpty),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                DialogHeader(
                  icon: Icons.tune,
                  title: l10n.anomaliesSettings,
                ),
                SwitchListTile(
                  key: const Key('anomaly-settings-enabled'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.enabled,
                  title: Text(l10n.anomaliesSettingsEnabled),
                  onChanged: (value) => setState(
                    () => _settings = settings.copyWith(enabled: value),
                  ),
                ),
                for (final rule in AnomalyRule.values)
                  SwitchListTile(
                    key: Key('anomaly-settings-rule-${rule.wire}'),
                    contentPadding: EdgeInsets.zero,
                    value: !settings.disabledRules.contains(rule),
                    title: Text(anomalyRuleLabel(context, rule)),
                    onChanged: (enabled) => setState(() {
                      final disabled = {...settings.disabledRules};
                      if (enabled) {
                        disabled.remove(rule);
                      } else {
                        disabled.add(rule);
                      }
                      _settings = settings.copyWith(disabledRules: disabled);
                    }),
                  ),
                const SizedBox(height: Space.sm),
                _number(
                  context,
                  'window_days',
                  l10n.anomaliesSettingsWindowDays,
                  settings.windowDays,
                ),
                _number(
                  context,
                  'shortage_min_amount',
                  l10n.anomaliesSettingsShortageMinAmount,
                  settings.shortageMinAmount,
                ),
                _number(
                  context,
                  'shortage_min_shifts',
                  l10n.anomaliesSettingsShortageMinShifts,
                  settings.shortageMinShifts,
                ),
                _number(
                  context,
                  'lost_ticket_min_closed',
                  l10n.anomaliesSettingsLostTicketMinClosed,
                  settings.lostTicketMinClosed,
                ),
                _number(
                  context,
                  'lost_ticket_min_rate_pct',
                  l10n.anomaliesSettingsLostTicketMinRatePct,
                  settings.lostTicketMinRatePct,
                ),
                _number(
                  context,
                  'lost_ticket_factor_pct',
                  l10n.anomaliesSettingsLostTicketFactorPct,
                  settings.lostTicketFactorPct,
                ),
                _number(
                  context,
                  'adjustment_min_amount',
                  l10n.anomaliesSettingsAdjustmentMinAmount,
                  settings.adjustmentMinAmount,
                ),
                _number(
                  context,
                  'short_stay_minutes',
                  l10n.anomaliesSettingsShortStayMinutes,
                  settings.shortStayMinutes,
                ),
                _number(
                  context,
                  'discount_min_count',
                  l10n.anomaliesSettingsDiscountMinCount,
                  settings.discountMinCount,
                ),
                _number(
                  context,
                  'discount_share_pct',
                  l10n.anomaliesSettingsDiscountSharePct,
                  settings.discountSharePct,
                ),
                _number(
                  context,
                  'shift_open_hours',
                  l10n.anomaliesSettingsShiftOpenHours,
                  settings.shiftOpenHours,
                ),
                _number(
                  context,
                  'session_open_days',
                  l10n.anomaliesSettingsSessionOpenDays,
                  settings.sessionOpenDays,
                ),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: Space.md),
                FilledButton(
                  key: const Key('anomaly-settings-save'),
                  onPressed: _saving ? null : () => _save(settings),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.actionSave),
                ),
              ],
            ),
    );
  }

  Widget _number(
    BuildContext context,
    String key,
    String label,
    int value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: TextField(
      key: Key('anomaly-settings-$key'),
      controller: _controller(key, value),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Future<void> _save(AnomalySettings base) async {
    final l10n = context.l10n;
    int? value(String key) => int.tryParse(_fields[key]?.text.trim() ?? '');
    final next = base.copyWith(
      windowDays: value('window_days') ?? base.windowDays,
      shortageMinAmount:
          value('shortage_min_amount') ?? base.shortageMinAmount,
      shortageMinShifts:
          value('shortage_min_shifts') ?? base.shortageMinShifts,
      lostTicketMinClosed:
          value('lost_ticket_min_closed') ?? base.lostTicketMinClosed,
      lostTicketMinRatePct:
          value('lost_ticket_min_rate_pct') ?? base.lostTicketMinRatePct,
      lostTicketFactorPct:
          value('lost_ticket_factor_pct') ?? base.lostTicketFactorPct,
      adjustmentMinAmount:
          value('adjustment_min_amount') ?? base.adjustmentMinAmount,
      shortStayMinutes:
          value('short_stay_minutes') ?? base.shortStayMinutes,
      discountMinCount: value('discount_min_count') ?? base.discountMinCount,
      discountSharePct: value('discount_share_pct') ?? base.discountSharePct,
      shiftOpenHours: value('shift_open_hours') ?? base.shiftOpenHours,
      sessionOpenDays: value('session_open_days') ?? base.sessionOpenDays,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AnomaliesCubit>().saveSettings(next);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.anomaliesSettingsSaved)),
        );
      }
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.failure(failure);
        });
      }
    }
  }
}
