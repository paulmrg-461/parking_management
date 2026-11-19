import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/report_assistant_cubit.dart';
import '../domain/entities/assistant_answer.dart';
import '../domain/entities/assistant_progress.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_turn.dart';
import '../domain/figure_verifier.dart';
import 'answer_export.dart';
import 'figure_format.dart';

/// Admin chat over the report RPCs. Every figure is resolved server-side from
/// a real report result and re-verified here from its raw sources.
class ReportAssistantPage extends StatefulWidget {
  const ReportAssistantPage({super.key});

  @override
  State<ReportAssistantPage> createState() => _ReportAssistantPageState();
}

class _ReportAssistantPageState extends State<ReportAssistantPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    _controller.clear();
    await context.read<ReportAssistantCubit>().ask(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantTitle),
        actions: [
          IconButton(
            key: const Key('assistant_clear'),
            tooltip: l10n.assistantClear,
            onPressed: context.read<ReportAssistantCubit>().clear,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: BlocBuilder<ReportAssistantCubit, ReportAssistantState>(
        builder: (context, state) => switch (state) {
          AssistantLoading() => const SkeletonList(),
          AssistantNotConfigured() => _NotConfigured(),
          AssistantFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: context.read<ReportAssistantCubit>().load,
            ),
          ),
          AssistantReady(:final turns, :final status) => Column(
            children: [
              _Banner(status: status),
              Expanded(
                child: turns.isEmpty
                    ? _Empty(onAsk: _ask)
                    : ListView.builder(
                        padding: const EdgeInsets.all(Space.md),
                        itemCount: turns.length,
                        itemBuilder: (context, index) => _TurnCard(
                          turn: turns[index],
                          onRetry: (id) =>
                              context.read<ReportAssistantCubit>().retry(id),
                        ),
                      ),
              ),
              _Composer(controller: _controller, onSend: _ask),
            ],
          ),
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.status});

  final AssistantStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Wrap(
        spacing: Space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.assistantPrivacyNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          StatusChip(
            label: l10n.assistantBudgetLeft(status.remainingRequests),
            tone: StatusTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAsk});

  final Future<void> Function(String) onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestions = [
      l10n.assistantSuggestRevenueMonth,
      l10n.assistantSuggestBusiestHour,
      l10n.assistantSuggestReservations,
      l10n.assistantSuggestCompare,
      l10n.assistantSuggestCash,
      l10n.assistantSuggestFull,
    ];
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: Space.md),
        Text(
          l10n.assistantEmptyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Space.xs),
        Text(l10n.assistantEmptyMessage, textAlign: TextAlign.center),
        const SizedBox(height: Space.md),
        Text(
          l10n.assistantSuggestionsTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final (index, suggestion) in suggestions.indexed)
              ActionChip(
                key: Key('assistant_suggestion_$index'),
                label: Text(suggestion),
                onPressed: () => onAsk(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({required this.turn, required this.onRetry});

  final AssistantTurn turn;
  final ValueChanged<int> onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(turn.question),
            ),
          ),
          const SizedBox(height: Space.xs),
          if (turn.answer case final answer?)
            _AnswerCard(answer: answer),
          if (turn.isRunning) ...[
            for (final tool in turn.tools) _ToolTile(tool: tool),
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                l10n.assistantThinking,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (turn.failure case final failure?)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.failure(failure),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  TextButton(
                    key: Key('assistant_retry_${turn.id}'),
                    onPressed: () => onRetry(turn.id),
                    child: Text(l10n.actionRetry),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _toolLabel(String tool, AppLocalizations l10n) => switch (tool) {
  'get_revenue_report' => l10n.assistantSuggestRevenueMonth,
  'get_hourly_traffic' => l10n.assistantSuggestBusiestHour,
  'get_reservations_report' => l10n.assistantSuggestReservations,
  'get_whatsapp_report' => 'WhatsApp',
  'get_occupancy_now' || 'get_capacity_now' => l10n.assistantSuggestFull,
  'get_today_summary' => l10n.assistantSuggestFull,
  'get_daily_trend' => l10n.assistantSuggestCompare,
  'get_shift_summaries' => l10n.assistantSuggestCash,
  _ => tool,
};

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final ToolProgress tool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = tool.state == ToolState.done;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.hourglass_top,
            size: 16,
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              done
                  ? l10n.assistantToolDone(_toolLabel(tool.tool, l10n))
                  : l10n.assistantToolRunning(_toolLabel(tool.tool, l10n)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AssistantAnswer answer;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showInfoSnack(context, context.l10n.assistantCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('assistant_answer_card'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (answer.status != AnswerStatus.answered)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: StatusChip(
                  label: switch (answer.status) {
                    AnswerStatus.needsClarification =>
                      l10n.assistantStatusNeedsClarification,
                    AnswerStatus.outOfScope => l10n.assistantStatusOutOfScope,
                    AnswerStatus.noData => l10n.assistantStatusNoData,
                    AnswerStatus.answered => '',
                  },
                  tone: StatusTone.neutral,
                ),
              ),
            Text(
              FigureFormatter.headline(answer, l10n, locale),
              style: theme.textTheme.titleSmall,
            ),
            if (answer.explanation.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(
                FigureFormatter.explanation(answer, l10n, locale),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (answer.figures.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(
                l10n.assistantFigures,
                style: theme.textTheme.labelLarge,
              ),
              for (final figure in answer.figures)
                _FigureTile(answer: answer, figure: figure),
            ],
            for (final caveat in answer.caveats)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(caveat, style: theme.textTheme.bodySmall),
              ),
            if (answer.questionRedacted)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  l10n.assistantRedacted,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                TextButton.icon(
                  key: const Key('assistant_copy_answer'),
                  onPressed: () => _copy(
                    context,
                    answerAsText(answer, l10n, currency: answer.currency),
                  ),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(l10n.assistantCopyAnswer),
                ),
                TextButton.icon(
                  key: const Key('assistant_copy_figures'),
                  onPressed: () =>
                      _copy(context, answerFiguresCsv(answer)),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: Text(l10n.assistantCopyFigures),
                ),
              ],
            ),
            Text(
              l10n.assistantDisclaimer,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureTile extends StatelessWidget {
  const _FigureTile({required this.answer, required this.figure});

  final AssistantAnswer answer;
  final AssistantFigure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final verified = FigureVerifier.verify(figure);
    final theme = Theme.of(context);
    return InkWell(
      key: Key('assistant_figure_${figure.id}'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _SourceSheet(answer: answer, figure: figure),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.warning_amber,
              size: 18,
              color: verified
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: Space.xs),
            Expanded(child: Text(figure.label)),
            Text(
              FigureFormatter.format(
                figure,
                answer.currency,
                l10n,
                locale,
              ),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.answer, required this.figure});

  final AssistantAnswer answer;
  final AssistantFigure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assistantSourceTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Space.sm),
          for (final source in figure.sources) ...[
            Text(l10n.assistantSourceReport(source.rpc)),
            Text(
              l10n.assistantSourceArgs(
                source.args.entries
                    .map((entry) => '${entry.key}=${entry.value}')
                    .join(', '),
              ),
            ),
            Text(l10n.assistantSourcePath(source.path)),
            Text(
              l10n.assistantSourceRaw(
                Money.formatAs(answer.currency, source.raw),
              ),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: Space.md),
            Text(
              l10n.assistantNotConfiguredTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.assistantNotConfiguredMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('assistant_composer'),
                controller: controller,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.assistantInputHint,
                  counterText: '',
                ),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(
              key: const Key('assistant_send'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(Layout.minTouch, Layout.minTouch),
              ),
              onPressed: () => onSend(controller.text),
              child: Text(l10n.assistantSend),
            ),
          ],
        ),
      ),
    );
  }
}
