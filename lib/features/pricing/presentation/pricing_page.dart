import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/pricing_cubit.dart';
import '../domain/entities/pricing_rule.dart';
import 'pricing_rule_dialog.dart';
import 'pricing_settings_card.dart';
import 'pricing_simulation_sheet.dart';

/// Admin screen: dynamic-pricing rules and their guard rails.
class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<PricingCubit>().load());
  }

  Future<void> _openRule(BuildContext context, {PricingRule? rule}) async {
    final draft = await showPricingRuleDialog(context, rule: rule);
    if (draft == null || !context.mounted) {
      return;
    }
    await context.read<PricingCubit>().saveRule(draft);
  }

  Future<void> _delete(BuildContext context, PricingRule rule) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.pricingRuleDeleteConfirm,
        body: rule.name,
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<PricingCubit>().deleteRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pricingTitle),
        actions: [
          IconButton(
            key: const Key('pricing_simulate'),
            tooltip: l10n.pricingSimulate,
            onPressed: () => showPricingSimulationSheet(context),
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('pricing_add_rule'),
        onPressed: () => unawaited(_openRule(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.pricingAddRule),
      ),
      body: BlocConsumer<PricingCubit, PricingState>(
        listenWhen: (previous, current) =>
            current is PricingLoaded &&
            previous is PricingLoaded &&
            current.submission != previous.submission,
        listener: (context, state) {
          if (state is! PricingLoaded) {
            return;
          }
          final submission = state.submission;
          if (submission is SubmissionSucceeded) {
            showInfoSnack(context, l10n.pricingRuleSaved);
          } else if (submission is SubmissionFailed) {
            final failed = submission;
            showErrorSnack(
              context,
              l10n.errorText(failed.message, failed.failure),
            );
          }
        },
        builder: (context, state) => switch (state) {
          PricingInitial() || PricingLoading() => const SkeletonList(),
          PricingFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: context.read<PricingCubit>().load,
            ),
          ),
          PricingLoaded(:final rules, :final settings) => ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.md,
              Space.md,
              Space.xxl,
            ),
            children: [
              PricingSettingsCard(
                settings: settings,
                onSave: (next) =>
                    context.read<PricingCubit>().saveSettings(next),
              ),
              const SizedBox(height: Space.md),
              if (rules.isEmpty)
                EmptyState(
                  message: l10n.pricingNoRulesHint,
                  title: l10n.pricingNoRules,
                  icon: Icons.trending_up_outlined,
                  action: FilledButton.icon(
                    onPressed: () => unawaited(_openRule(context)),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.pricingAddRule),
                  ),
                )
              else
                for (final rule in rules)
                  _RuleCard(
                    rule: rule,
                    onToggle: () =>
                        context.read<PricingCubit>().toggleRule(rule),
                    onEdit: () => unawaited(_openRule(context, rule: rule)),
                    onDelete: () => unawaited(_delete(context, rule)),
                  ),
            ],
          ),
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PricingRule rule;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _summary(BuildContext context) {
    final l10n = context.l10n;
    final group = rule.group ?? l10n.pricingRuleGroupAll;
    final when = [
      if (rule.minOccupancyPct != null || rule.maxOccupancyPct != null)
        '${rule.minOccupancyPct ?? 0}-${rule.maxOccupancyPct ?? 100} %',
      if (rule.fromMinute != null)
        '${wireFromMinutes(rule.fromMinute)}-${wireFromMinutes(rule.toMinute)}',
      if (rule.weekdays != null) rule.weekdaySet.join(','),
    ].join(' · ');
    final effect = [
      if (rule.hasMultiplier) '${rule.multiplierBps ~/ 100} %',
      if (rule.hasSurcharge) Money.format(rule.surchargeAmount),
    ].join(' + ');
    return l10n.pricingRuleSummary(group, when, effect);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(rule.name)),
            if (rule.hasSurcharge)
              StatusChip(
                label: '+${Money.format(rule.surchargeAmount)}',
                tone: StatusTone.warning,
              ),
          ],
        ),
        subtitle: Text(_summary(context)),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '${l10n.pricingRuleActive}: ${rule.name}',
              child: Switch(
                key: Key('pricing_rule_toggle_${rule.id}'),
                value: rule.active,
                onChanged: (_) => onToggle(),
              ),
            ),
            IconButton(
              tooltip: l10n.actionDelete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
