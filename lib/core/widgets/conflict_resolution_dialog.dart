import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/failure_messages.dart';
import '../l10n/l10n.dart';
import '../sync/conflict/conflict_resolution_cubit.dart';
import '../sync/conflict/entity_fields.dart';
import '../sync/sync_outbox.dart';
import '../theme/tokens.dart';
import 'confirm_dialog.dart';
import 'dialog_header.dart';

/// Field-by-field resolution of one parked conflict.
///
/// Opens in three shapes (see [ConflictKind]): both sides edited, my edit met a
/// deletion, my delete met an edit. Resolves with `true` once the choice lands
/// so the caller can refresh its list.
class ConflictResolutionDialog extends StatefulWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.entry,
    required this.apply,
    this.seenVersion,
  });

  final OutboxEntry entry;

  /// `SyncStatusCubit.resolve`, injected so the dialog stays testable.
  final ResolutionApplier apply;

  /// The server version the dialog showed last time; a different one means the
  /// record changed again and the values must be re-read.
  final int? seenVersion;

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  late final ConflictResolutionCubit _cubit = ConflictResolutionCubit(
    entry: widget.entry,
    apply: widget.apply,
    conflictAgain: _changedAgain,
  );

  bool get _changedAgain {
    final seen = widget.seenVersion;
    final current = widget.entry.value.decodeServerRow()?['version'];
    return seen != null && current is num && current.toInt() != seen;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<ConflictResolutionCubit, ConflictResolutionState>(
        listener: (context, state) {
          if (state is ConflictResolutionDone) {
            Navigator.of(context).pop(true);
          }
        },
        builder: (context, state) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, ConflictResolutionState state) {
    final entry = state.entry;
    final kind = kindOf(entry.value);
    final submitting = state is ConflictResolutionSubmitting;
    return AlertDialog(
      title: _title(context, kind, state),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state is ConflictResolutionIdle && state.conflictAgain) ...[
                _Banner(text: context.l10n.conflictAgain),
                const SizedBox(height: Space.sm),
              ],
              ..._content(context, state, kind, submitting),
              if (state is ConflictResolutionFailed) ...[
                const SizedBox(height: Space.sm),
                Text(
                  context.l10n.failure(state.failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _actions(context, state, kind, submitting),
    );
  }

  Widget _title(
    BuildContext context,
    ConflictKind kind,
    ConflictResolutionState state,
  ) {
    final l10n = context.l10n;
    final (icon, text, subtitle) = switch (kind) {
      ConflictKind.deleted => (
        Icons.delete_outline,
        l10n.conflictDeletedTitle,
        l10n.conflictDeletedBody,
      ),
      ConflictKind.deletedElsewhere => (
        Icons.edit_outlined,
        l10n.conflictEditedTitle,
        l10n.conflictIntro,
      ),
      ConflictKind.edited => (
        Icons.merge_type,
        l10n.conflictTitle,
        l10n.conflictIntro,
      ),
    };
    return DialogHeader(icon: icon, title: text, subtitle: subtitle);
  }

  List<Widget> _content(
    BuildContext context,
    ConflictResolutionState state,
    ConflictKind kind,
    bool submitting,
  ) {
    if (state is! ConflictResolutionIdle || kind != ConflictKind.edited) {
      return const [];
    }
    final l10n = context.l10n;
    final plan = state.plan;
    final entity = state.entry.value.entityType;
    return [
      if (plan.autoApply.isNotEmpty) ...[
        Text(
          l10n.conflictAutoMerged(plan.autoApply.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.sm),
      ],
      if (plan.conflicts.isEmpty)
        Text(l10n.conflictEmpty)
      else ...[
        Text(l10n.conflictPickEach),
        const SizedBox(height: Space.sm),
        for (final conflict in plan.conflicts)
          if (fieldFor(entity, conflict.field) case final spec?)
            _FieldRow(
              spec: spec,
              field: conflict.field,
              base: conflict.base,
              mine: conflict.mine,
              theirs: conflict.theirs,
              mineSelected: state.mineFields.contains(conflict.field),
              enabled: !submitting,
              onChoose: (mine) => context
                  .read<ConflictResolutionCubit>()
                  .choose(conflict.field, mine: mine),
            ),
      ],
    ];
  }

  List<Widget> _actions(
    BuildContext context,
    ConflictResolutionState state,
    ConflictKind kind,
    bool submitting,
  ) {
    final l10n = context.l10n;
    final cubit = context.read<ConflictResolutionCubit>();
    final idle = state is ConflictResolutionIdle ? state : null;
    final retry = state is ConflictResolutionFailed;

    if (kind == ConflictKind.deleted) {
      return [
        _action(
          key: 'conflict-accept-deletion',
          label: l10n.conflictAcceptDeletion,
          onPressed: submitting
              ? null
              : () => _confirm(
                  title: l10n.conflictDeletedTitle,
                  body: l10n.conflictDeletedBody,
                  confirm: l10n.conflictAcceptDeletion,
                  onConfirm: cubit.acceptDeletion,
                ),
        ),
      ];
    }

    if (kind == ConflictKind.deletedElsewhere) {
      return [
        _action(
          key: 'conflict-keep-delete',
          label: l10n.conflictKeepDelete,
          destructive: true,
          onPressed: submitting
              ? null
              : () => _confirm(
                  title: l10n.conflictEditedTitle,
                  body: l10n.conflictIntro,
                  confirm: l10n.conflictKeepDelete,
                  onConfirm: cubit.keepDelete,
                ),
        ),
        _action(
          key: 'conflict-keep-record',
          label: l10n.conflictKeepRecord,
          onPressed: submitting ? null : cubit.keepTheirs,
        ),
      ];
    }

    return [
      if (retry)
        _action(
          key: 'conflict-retry',
          label: l10n.actionRetry,
          onPressed: cubit.retry,
        ),
      _action(
        key: 'conflict-keep-theirs',
        label: l10n.syncKeepTheirs,
        onPressed: submitting ? null : cubit.keepTheirs,
      ),
      _action(
        key: 'conflict-keep-mine',
        label: l10n.syncKeepMine,
        onPressed: submitting ? null : cubit.keepMine,
      ),
      _action(
        key: 'conflict-apply',
        label: l10n.conflictApply,
        submitting: submitting,
        onPressed: submitting || idle == null || !idle.complete
            ? null
            : cubit.apply,
      ),
    ];
  }

  Widget _action({
    required String key,
    required String label,
    VoidCallback? onPressed,
    bool destructive = false,
    bool submitting = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final child = submitting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    return FilledButton(
      key: Key(key),
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null,
      onPressed: onPressed,
      child: child,
    );
  }

  Future<void> _confirm({
    required String title,
    required String body,
    required String confirm,
    required Future<void> Function() onConfirm,
  }) async {
    final accepted = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirm,
        destructive: true,
      ),
    );
    if (accepted) {
      await onConfirm();
    }
  }
}

/// One conflicting field: what it was, and the two values to choose from.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.spec,
    required this.field,
    required this.base,
    required this.mine,
    required this.theirs,
    required this.mineSelected,
    required this.enabled,
    required this.onChoose,
  });

  final FieldSpec spec;
  final String field;
  final Object? base;
  final Object? mine;
  final Object? theirs;
  final bool mineSelected;
  final bool enabled;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(spec.label(l10n), style: theme.textTheme.labelLarge),
          Text(
            '${l10n.conflictColumnBase}: ${spec.formatWith(l10n, base)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: _chip(
                  key: 'conflict-mine-$field',
                  label: l10n.conflictColumnMine,
                  value: spec.formatWith(l10n, mine),
                  selected: mineSelected,
                  onSelected: enabled ? () => onChoose(true) : null,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _chip(
                  key: 'conflict-theirs-$field',
                  label: l10n.conflictColumnTheirs,
                  value: spec.formatWith(l10n, theirs),
                  selected: !mineSelected,
                  onSelected: enabled ? () => onChoose(false) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String key,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback? onSelected,
  }) {
    return ChoiceChip(
      key: Key(key),
      label: Text('$label: $value'),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
    );
  }
}
