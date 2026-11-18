import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/pricing_simulation_cubit.dart';
import '../domain/entities/pricing_rule.dart';

Future<void> showPricingSimulationSheet(
  BuildContext context, {
  PricingRuleDraft? draft,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider<PricingSimulationCubit>.value(
    value: context.read<PricingSimulationCubit>(),
    child: PricingSimulationSheet(draft: draft),
  ),
);

/// Read-only replay of the rules over the last N days.
class PricingSimulationSheet extends StatefulWidget {
  const PricingSimulationSheet({super.key, this.draft});

  /// Optional unsaved rule sent as a candidate.
  final PricingRuleDraft? draft;

  @override
  State<PricingSimulationSheet> createState() => _PricingSimulationSheetState();
}

class _PricingSimulationSheetState extends State<PricingSimulationSheet> {
  int _days = 30;
  bool _includeDraft = false;

  void _run() {
    context.read<PricingSimulationCubit>().run(
      days: _days,
      candidates: _includeDraft && widget.draft != null
          ? [widget.draft!]
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _run();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(Space.md),
        children: [
          Text(l10n.pricingSimulate, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final days in [7, 30, 90])
                ChoiceChip(
                  label: Text(l10n.pricingSimulateDays(days)),
                  selected: _days == days,
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
          if (widget.draft != null)
            SwitchListTile(
              key: const Key('pricing_sim_include_draft'),
              contentPadding: EdgeInsets.zero,
              value: _includeDraft,
              onChanged: (value) => setState(() => _includeDraft = value),
              title: Text(l10n.pricingSimIncludeDraft),
            ),
          FilledButton(
            key: const Key('pricing_sim_run'),
            onPressed: _run,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l10n.pricingSimulate),
          ),
          const SizedBox(height: Space.md),
          BlocBuilder<PricingSimulationCubit, PricingSimulationState>(
            builder: (context, state) => switch (state) {
              SimulationIdle() || SimulationRunning() => const Column(
                children: [
                  SkeletonCard(),
                  SizedBox(height: Space.sm),
                  SkeletonCard(),
                ],
              ),
              SimulationFailure(:final failure) => ErrorState(
                message: l10n.failure(failure),
                onRetry: _run,
              ),
              SimulationDone(:final result) => result.isEmpty
                  ? Text(l10n.pricingSimEmpty)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                icon: Icons.payments_outlined,
                                label: l10n.pricingSimBase,
                                value: Money.format(result.baseTotal),
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: MetricCard(
                                icon: Icons.trending_up,
                                label: l10n.pricingSimTotal,
                                value: Money.format(result.simulatedTotal),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                icon: Icons.difference_outlined,
                                label: l10n.pricingSimDelta,
                                value: Money.format(result.delta),
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: MetricCard(
                                icon: Icons.route_outlined,
                                label: l10n.pricingSimByRule,
                                value: l10n.pricingSimAffected(
                                  result.sessionsAffected,
                                ),
                                caption: l10n.pricingSimAtLimits(
                                  result.atFloor,
                                  result.atCeiling,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Text(
                          l10n.pricingSimByRule,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final row in result.byRule)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(row.name),
                            subtitle: Text('${row.sessions}'),
                            trailing: Text(Money.format(row.delta)),
                          ),
                        if (result.byHour.isNotEmpty) ...[
                          const SizedBox(height: Space.sm),
                          Text(
                            l10n.pricingSimByHour,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          for (final hour in result.byHour)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${hour.hour}:00'),
                              subtitle: Text('${hour.sessions}'),
                              trailing: Text(Money.format(hour.delta)),
                            ),
                        ],
                        const SizedBox(height: Space.sm),
                        Text(
                          l10n.pricingSimNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            },
          ),
        ],
      ),
    );
  }
}
