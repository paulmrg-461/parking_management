import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/damage_comparison_cubit.dart';
import '../domain/entities/damage_comparison.dart';

class DamageComparisonPage extends StatefulWidget {
  const DamageComparisonPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<DamageComparisonPage> createState() => _DamageComparisonPageState();
}

class _DamageComparisonPageState extends State<DamageComparisonPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<DamageComparisonCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.damageTitle)),
      body: BlocBuilder<DamageComparisonCubit, DamageState>(
        builder: (context, state) => switch (state) {
          DamageLoading() => const SkeletonList(),
          DamageNotConfigured() => Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Text(l10n.damageNotConfigured, textAlign: TextAlign.center),
            ),
          ),
          DamageFailure(:final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.failure(failure),
              onRetry: context.read<DamageComparisonCubit>().load,
            ),
          ),
          DamageLoaded(:final view, :final running, :final failure) =>
            _Loaded(
              view: view,
              running: running,
              failure: failure,
              onRun: context.read<DamageComparisonCubit>().run,
              onReview: (id, status, note) =>
                  context.read<DamageComparisonCubit>().review(id, status, note),
            ),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.view,
    required this.running,
    required this.failure,
    required this.onRun,
    required this.onReview,
  });

  final DamageView view;
  final bool running;
  final dynamic failure;
  final VoidCallback onRun;
  final Future<void> Function(int, FindingReview, String) onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comparison = view.comparison;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.damageAdvisoryTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Space.xs),
                Text(l10n.damageAdvisoryBody),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        if (failure != null)
          Text(
            l10n.failure(failure),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (comparison == null)
          Column(
            children: [
              const SizedBox(height: Space.lg),
              Text(
                l10n.damageEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Space.xs),
              Text(l10n.damageEmptyNeedExit, textAlign: TextAlign.center),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                key: const Key('damage_run'),
                onPressed: running ? null : onRun,
                icon: const Icon(Icons.compare_outlined),
                label: Text(running ? l10n.damageRunning : l10n.damageRun),
              ),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (comparison.overall) {
                    DamageOverall.none => l10n.damageVerdictNone,
                    DamageOverall.possible => l10n.damageVerdictPossible,
                    DamageOverall.insufficient =>
                      l10n.damageVerdictInsufficient,
                  },
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (view.stale)
                const StatusChip(label: 'stale', tone: StatusTone.warning),
            ],
          ),
          if (comparison.summary.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(comparison.summary),
          ],
          const SizedBox(height: Space.md),
          for (final finding in comparison.findings)
            Card(
              key: Key('damage_finding_${finding.id}'),
              margin: const EdgeInsets.only(bottom: Space.sm),
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(finding.description)),
                        StatusChip(
                          label: switch (finding.classification) {
                            FindingClassification.preExisting =>
                              l10n.damageClassPre,
                            FindingClassification.newDamage =>
                              l10n.damageClassNew,
                            FindingClassification.uncertain =>
                              l10n.damageClassUncertain,
                          },
                          tone: finding.classification ==
                                  FindingClassification.newDamage
                              ? StatusTone.warning
                              : StatusTone.neutral,
                        ),
                      ],
                    ),
                    Text(finding.zone.name),
                    if (finding.isDowngraded)
                      Text(l10n.damageClassUncertain),
                    if (finding.reviewNote != null)
                      Text('${finding.reviewNote}'),
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        TextButton(
                          key: Key('damage_confirm_${finding.id}'),
                          onPressed: () => _review(
                            context,
                            finding,
                            FindingReview.confirmed,
                          ),
                          child: Text(l10n.damageReviewConfirm),
                        ),
                        TextButton(
                          key: Key('damage_dismiss_${finding.id}'),
                          onPressed: () => _review(
                            context,
                            finding,
                            FindingReview.dismissed,
                          ),
                          child: Text(l10n.damageReviewDismiss),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            key: const Key('damage_rerun'),
            onPressed: running ? null : onRun,
            icon: const Icon(Icons.refresh),
            label: Text(running ? l10n.damageRunning : l10n.damageRerun),
          ),
        ],
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    DamageFinding finding,
    FindingReview status,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(status: status),
    );
    if (note != null) {
      await onReview(finding.id, status, note);
    }
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.status});
  final FindingReview status;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _note.text.trim();
    if (value.length < 3 || value.length > 400) {
      setState(() => _error = context.l10n.errorInvalidData);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('damage_review_dialog'),
      title: Text(
        widget.status == FindingReview.confirmed
            ? l10n.damageReviewConfirm
            : l10n.damageReviewDismiss,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('damage_review_note'),
              controller: _note,
              maxLength: 400,
              decoration: InputDecoration(
                labelText: l10n.damageReviewNoteLabel,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Text(l10n.damageReviewAudited),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('damage_review_save'),
          onPressed: _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
