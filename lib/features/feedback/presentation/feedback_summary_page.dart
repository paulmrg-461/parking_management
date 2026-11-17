import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/feedback_summary_cubit.dart';
import '../domain/entities/feedback_summary.dart';

/// Admin-only customer satisfaction report (`/satisfaction`).
class FeedbackSummaryPage extends StatefulWidget {
  const FeedbackSummaryPage({super.key});

  @override
  State<FeedbackSummaryPage> createState() => _FeedbackSummaryPageState();
}

class _FeedbackSummaryPageState extends State<FeedbackSummaryPage> {
  static const _periods = [7, 30, 90];

  int _days = 30;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<FeedbackSummaryCubit>().load(_days));
  }

  void _select(int days) {
    if (days == _days) {
      return;
    }
    setState(() => _days = days);
    unawaited(context.read<FeedbackSummaryCubit>().load(days));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackReportTitle)),
      body: BlocBuilder<FeedbackSummaryCubit, FeedbackSummaryState>(
        builder: (context, state) => switch (state) {
          FeedbackSummaryInitial() ||
          FeedbackSummaryLoading() => const SkeletonCardList(itemCount: 3),
          FeedbackSummaryFailure(:final failure) => ErrorState(
            message: l10n.failure(failure),
            onRetry: () =>
                unawaited(context.read<FeedbackSummaryCubit>().load(_days)),
          ),
          final FeedbackSummaryLoaded loaded => _Body(
            loaded: loaded,
            periods: _periods,
            onSelect: _select,
            onRefresh: () =>
                unawaited(context.read<FeedbackSummaryCubit>().load(_days)),
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.loaded,
    required this.periods,
    required this.onSelect,
    required this.onRefresh,
  });

  final FeedbackSummaryLoaded loaded;
  final List<int> periods;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = loaded.summary;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          FilterBar(
            summary: l10n.feedbackPeriodSummary(summary.total, loaded.days),
            children: [
              for (final days in periods)
                ChoiceChip(
                  key: Key('feedback-period-$days'),
                  label: Text(l10n.feedbackPeriodDays(days)),
                  selected: loaded.days == days,
                  onSelected: (_) => onSelect(days),
                ),
            ],
          ),
          if (loaded.refreshing)
            const Padding(
              padding: EdgeInsets.only(top: Space.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: Space.md),
          if (summary.isEmpty)
            EmptyState(
              icon: Icons.reviews_outlined,
              title: l10n.feedbackEmptyTitle,
              message: l10n.feedbackEmptyBody,
              action: FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.feedbackRefresh),
              ),
            )
          else ...[
            _Metrics(summary: summary),
            const SizedBox(height: Space.lg),
            SectionHeader(
              icon: Icons.star_outline,
              title: l10n.feedbackDistribution,
            ),
            const SizedBox(height: Space.sm),
            _Distribution(summary: summary),
            const SizedBox(height: Space.lg),
            SectionHeader(
              icon: Icons.chat_bubble_outline,
              title: l10n.feedbackRecent,
            ),
            const SizedBox(height: Space.sm),
            if (summary.recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(
                    l10n.feedbackRecentEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final entry in summary.recent) _FeedbackTile(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});

  final FeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final whole = summary.averageX10 ~/ 10;
    final decimal = summary.averageX10 % 10;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.star_half_outlined,
                  tone: MetricTone.primary,
                  label: l10n.feedbackAverage,
                  value: l10n.feedbackAverageValue(whole, decimal),
                  caption: l10n.feedbackAverageCaption(summary.total),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: MetricCard(
                  icon: Icons.reviews_outlined,
                  label: l10n.feedbackResponses,
                  value: '${summary.total}',
                  caption: l10n.feedbackResponseRate(
                    summary.responseRatePercent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        MetricCard(
          icon: Icons.thumb_down_outlined,
          tone: summary.lowCount > 0 ? MetricTone.warning : MetricTone.success,
          label: l10n.feedbackLowRatings,
          value: summary.lowCount > 0
              ? '${summary.lowCount}'
              : l10n.feedbackLowEmpty,
          caption: l10n.feedbackLowCaption,
        ),
      ],
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.summary});

  final FeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          children: [
            for (var rating = 5; rating >= 1; rating--) ...[
              Semantics(
                label: l10n.feedbackDistributionSemantics(
                  rating,
                  summary.countFor(rating),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          l10n.feedbackDistributionRow(rating),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: summary.countFor(rating) / summary.peak,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: switch (rating) {
                              1 || 2 => status.warning,
                              3 => status.pending,
                              _ => scheme.primary,
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${summary.countFor(rating)}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (rating > 1) const SizedBox(height: Space.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.entry});

  final FeedbackEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = switch (entry.rating) {
      <= 2 => StatusTone.warning,
      3 => StatusTone.pending,
      _ => StatusTone.success,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  label: '${entry.rating}',
                  tone: tone,
                  icon: Icons.star_rounded,
                ),
                PlateText(entry.plate),
                Text(
                  Formatters.date(entry.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              entry.comment.isEmpty ? l10n.feedbackNoComment : entry.comment,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: entry.comment.isEmpty ? scheme.onSurfaceVariant : null,
                fontStyle: entry.comment.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
