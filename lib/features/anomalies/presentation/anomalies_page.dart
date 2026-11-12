import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/anomalies_cubit.dart';
import '../domain/entities/cash_anomaly.dart';
import 'widgets/anomaly_resolve_dialog.dart';
import 'widgets/anomaly_settings_sheet.dart';
import 'widgets/anomaly_tile.dart';

/// Admin-only review of the cash anomalies the job detects.
class AnomaliesPage extends StatefulWidget {
  const AnomaliesPage({super.key});

  @override
  State<AnomaliesPage> createState() => _AnomaliesPageState();
}

class _AnomaliesPageState extends State<AnomaliesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<AnomaliesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.anomaliesTitle),
        actions: [
          AppIconButton(
            key: const Key('anomalies-settings'),
            icon: Icons.tune,
            tooltip: l10n.anomaliesSettings,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => BlocProvider.value(
                value: context.read<AnomaliesCubit>(),
                child: const AnomalySettingsSheet(),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<AnomaliesCubit, AnomaliesState>(
        builder: (context, state) => switch (state) {
          AnomaliesInitial() || AnomaliesLoading() => const SkeletonCardList(),
          AnomaliesFailure(:final failure) => ErrorState(
            message: context.l10n.failure(failure),
            onRetry: () => context.read<AnomaliesCubit>().load(),
          ),
          final AnomaliesLoaded loaded => _body(context, loaded),
        },
      ),
    );
  }

  Widget _body(BuildContext context, AnomaliesLoaded loaded) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () => context.read<AnomaliesCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          FilterBar(
            summary: l10n.anomaliesOpenCount(loaded.list.openCount),
            onClear: loaded.isFiltered
                ? () => context.read<AnomaliesCubit>().load(clearFilters: true)
                : null,
            clearLabel: l10n.anomaliesClearFilters,
            children: [
              Wrap(
                spacing: Space.xs,
                children: [
                  for (final status in [
                    AnomalyStatus.open,
                    AnomalyStatus.acknowledged,
                    AnomalyStatus.dismissed,
                  ])
                    ChoiceChip(
                      key: Key('anomalies-status-${status.wire}'),
                      label: Text(_statusLabel(context, status)),
                      selected: loaded.status == status,
                      onSelected: (_) =>
                          context.read<AnomaliesCubit>().load(status: status),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AnomalyRule?>(
                      key: const Key('anomalies-rule-filter'),
                      isExpanded: true,
                      initialValue: loaded.rule,
                      decoration: InputDecoration(
                        labelText: l10n.anomaliesRuleLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.anomaliesStatusAll),
                        ),
                        for (final rule in AnomalyRule.values)
                          DropdownMenuItem(
                            value: rule,
                            child: Text(anomalyRuleLabel(context, rule)),
                          ),
                      ],
                      onChanged: (rule) => rule == null
                          ? context.read<AnomaliesCubit>().load(
                              clearFilters: true,
                            )
                          : context.read<AnomaliesCubit>().load(rule: rule),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: DropdownButtonFormField<AnomalySeverity?>(
                      key: const Key('anomalies-severity-filter'),
                      isExpanded: true,
                      initialValue: loaded.severity,
                      decoration: InputDecoration(
                        labelText: l10n.anomaliesSeverityLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.anomaliesStatusAll),
                        ),
                        for (final severity in AnomalySeverity.values)
                          DropdownMenuItem(
                            value: severity,
                            child: Text(
                              anomalySeverityLabel(context, severity),
                            ),
                          ),
                      ],
                      onChanged: (severity) => severity == null
                          ? context.read<AnomaliesCubit>().load(
                              clearFilters: true,
                            )
                          : context.read<AnomaliesCubit>().load(
                              severity: severity,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (loaded.notice case final notice?)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                context.l10n.failure(notice),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: Space.md),
          if (loaded.list.isEmpty)
            EmptyState(
              icon: Icons.verified_outlined,
              title: l10n.anomaliesEmptyTitle,
              message: l10n.anomaliesEmpty,
              action: loaded.isFiltered
                  ? OutlinedButton(
                      onPressed: () => context.read<AnomaliesCubit>().load(
                        clearFilters: true,
                      ),
                      child: Text(l10n.anomaliesClearFilters),
                    )
                  : null,
            )
          else
            for (final anomaly in loaded.list.items)
              AnomalyTile(
                anomaly: anomaly,
                resolving: loaded.resolvingId == anomaly.id,
                onResolve: (status, note) => context
                    .read<AnomaliesCubit>()
                    .resolve(id: anomaly.id, status: status, note: note),
                onAudit: () => context.go(
                  '/audit?table=cash_anomalies&search=${anomaly.id}',
                ),
              ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, AnomalyStatus status) =>
      switch (status) {
        AnomalyStatus.open => context.l10n.anomaliesStatusOpen,
        AnomalyStatus.acknowledged => context.l10n.anomaliesStatusAcknowledged,
        AnomalyStatus.dismissed => context.l10n.anomaliesStatusDismissed,
      };
}

/// Localized rule name (shared by the page, the tile and the settings sheet).
String anomalyRuleLabel(BuildContext context, AnomalyRule rule) =>
    switch (rule) {
      AnomalyRule.shiftShortage => context.l10n.anomalyRuleShiftShortage,
      AnomalyRule.lostTicketRate => context.l10n.anomalyRuleLostTicketRate,
      AnomalyRule.postCloseAdjustment =>
        context.l10n.anomalyRulePostCloseAdjustment,
      AnomalyRule.zeroCharge => context.l10n.anomalyRuleZeroCharge,
      AnomalyRule.shortLostTicket => context.l10n.anomalyRuleShortLostTicket,
      AnomalyRule.discountRate => context.l10n.anomalyRuleDiscountRate,
      AnomalyRule.shiftOpenLong => context.l10n.anomalyRuleShiftOpenLong,
      AnomalyRule.sessionOpenLong => context.l10n.anomalyRuleSessionOpenLong,
    };

String anomalySeverityLabel(BuildContext context, AnomalySeverity severity) =>
    switch (severity) {
      AnomalySeverity.low => context.l10n.anomaliesSeverityLow,
      AnomalySeverity.medium => context.l10n.anomaliesSeverityMedium,
      AnomalySeverity.high => context.l10n.anomaliesSeverityHigh,
    };

/// Status chip tone for a severity (the red semantic colour stays for the
/// high, actionable ones).
StatusTone severityTone(AnomalySeverity severity) => switch (severity) {
  AnomalySeverity.high => StatusTone.warning,
  AnomalySeverity.medium => StatusTone.pending,
  AnomalySeverity.low => StatusTone.neutral,
};

/// One localized sentence describing the anomaly from its `details`.
String anomalyDescription(BuildContext context, CashAnomaly anomaly) {
  final l10n = context.l10n;
  return switch (anomaly.rule) {
    AnomalyRule.shiftShortage => l10n.anomalyDescShiftShortage(
      anomaly.detailInt('shifts'),
      '${anomaly.detailInt('total_shortage')}',
    ),
    AnomalyRule.lostTicketRate => l10n.anomalyDescLostTicketRate(
      '${anomaly.detailDouble('rate_pct') ?? 0}'.replaceAll('.0', ''),
      '${anomaly.detailDouble('baseline_pct') ?? 0}'.replaceAll('.0', ''),
    ),
    AnomalyRule.postCloseAdjustment => l10n.anomalyDescPostCloseAdjustment(
      '${anomaly.detailInt('old_difference')}',
      '${anomaly.detailInt('new_difference')}',
      anomaly.detailText('adjusted_by_name'),
    ),
    AnomalyRule.zeroCharge => l10n.anomalyDescZeroCharge(
      anomaly.plate ?? '',
      anomaly.detailText('payment_method'),
    ),
    AnomalyRule.shortLostTicket => l10n.anomalyDescShortLostTicket(
      anomaly.plate ?? '',
      anomaly.detailInt('stay_minutes'),
    ),
    AnomalyRule.discountRate => l10n.anomalyDescDiscountRate(
      anomaly.detailInt('discounts'),
      '${anomaly.detailDouble('share_pct') ?? 0}'.replaceAll('.0', ''),
    ),
    AnomalyRule.shiftOpenLong => l10n.anomalyDescShiftOpenLong(
      anomaly.detailInt('open_hours'),
    ),
    AnomalyRule.sessionOpenLong => l10n.anomalyDescSessionOpenLong(
      anomaly.plate ?? '',
      anomaly.detailInt('open_days'),
    ),
  };
}

/// Opens the acknowledge/dismiss dialog for [anomaly].
Future<void> showAnomalyResolveDialog(
  BuildContext context,
  CashAnomaly anomaly, {
  required Future<void> Function(AnomalyStatus status, String? note) onResolve,
}) => showDialog<void>(
  context: context,
  builder: (_) => AnomalyResolveDialog(anomaly: anomaly, onResolve: onResolve),
);
