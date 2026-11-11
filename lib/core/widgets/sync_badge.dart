import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../sync/conflict/conflict_resolution.dart';
import '../sync/pending_mutation.dart';
import '../theme/tokens.dart';
import '../sync/sync_outbox.dart';
import '../sync/sync_status_cubit.dart';

/// AppBar action showing how many offline changes are waiting to sync.
/// Hidden when the queue is empty (or no [SyncStatusCubit] is provided, e.g.
/// isolated widget tests); tap opens the dead-letter list.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = _maybeCubit(context);
    if (cubit == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      bloc: cubit,
      builder: (context, status) {
        if (!status.hasWork) {
          return const SizedBox.shrink();
        }
        final hasErrors = status.deadLetters.isNotEmpty;
        final hasConflicts = status.conflicts.isNotEmpty;
        return IconButton(
          tooltip: _tooltip(context.l10n, status),
          onPressed: () => _showDetails(context, cubit),
          icon: Badge(
            label: Text('${status.total}'),
            backgroundColor: hasErrors || hasConflicts
                ? Theme.of(context).colorScheme.error
                : null,
            child: Icon(
              hasErrors
                  ? Icons.sync_problem
                  : hasConflicts
                  ? Icons.merge_type
                  : Icons.sync,
            ),
          ),
        );
      },
    );
  }

  SyncStatusCubit? _maybeCubit(BuildContext context) {
    try {
      return context.read<SyncStatusCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  String _tooltip(AppLocalizations l10n, SyncStatus status) {
    final base = l10n.syncPendingTooltip(status.total);
    final errors = status.deadLetters.length;
    final withErrors = errors == 0
        ? base
        : l10n.syncPendingWithErrors(base, errors);
    return status.conflicts.isEmpty
        ? withErrors
        : '$withErrors · ${l10n.syncConflicts(status.conflicts.length)}';
  }

  void _showDetails(BuildContext context, SyncStatusCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _SyncDetailsSheet()),
    );
  }
}

class _SyncDetailsSheet extends StatelessWidget {
  const _SyncDetailsSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, status) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          children: [
            Text(
              context.l10n.syncSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.sm),
            if (status.pendingCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.read<SyncStatusCubit>().syncNow(),
                  icon: const Icon(Icons.sync),
                  label: Text(context.l10n.syncNow),
                ),
              ),
            Text(context.l10n.syncQueued(status.pendingCount)),
            if (status.conflicts.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(
                context.l10n.syncConflicts(status.conflicts.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final entry in status.conflicts) _ConflictTile(entry),
            ],
            for (final entry in status.deadLetters) _DeadLetterTile(entry),
          ],
        ),
      ),
    );
  }
}

/// A parked conflict: the operator picks which side wins.
class _ConflictTile extends StatelessWidget {
  const _ConflictTile(this.entry);

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final mutation = entry.value;
    final id = mutation.entityId == null ? '' : ' #${mutation.entityId}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.merge_type),
      title: Text(
        '${_DeadLetterTile._label(context.l10n, mutation.entityType)}$id',
      ),
      subtitle: Text(context.l10n.syncConflictHint),
      trailing: TextButton(
        key: Key('sync-resolve-${entry.key}'),
        onPressed: () => _resolve(context, mutation),
        child: Text(context.l10n.syncConflictTitle),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, PendingMutation mutation) async {
    final resolution = await showDialog<ConflictResolution>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.syncConflictTitle),
        content: Text(context.l10n.syncConflictHint),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const KeepTheirs()),
            child: Text(context.l10n.syncKeepTheirs),
          ),
          FilledButton(
            key: const Key('sync-keep-mine'),
            onPressed: () => Navigator.of(dialogContext).pop(const KeepMine()),
            child: Text(context.l10n.syncKeepMine),
          ),
        ],
      ),
    );
    if (resolution != null && context.mounted) {
      await context.read<SyncStatusCubit>().resolve(entry.key, resolution);
    }
  }
}

class _DeadLetterTile extends StatelessWidget {
  const _DeadLetterTile(this.entry);

  final OutboxEntry entry;

  static String _label(AppLocalizations l10n, MutationEntity entity) =>
      switch (entity) {
        MutationEntity.vehicle => l10n.entityVehicle,
        MutationEntity.tariff => l10n.entityTariff,
        MutationEntity.category => l10n.entityCategory,
        MutationEntity.checkIn => l10n.entityCheckIn,
        MutationEntity.checkOut => l10n.entityCheckOut,
        MutationEntity.settings => l10n.entitySettings,
      };

  @override
  Widget build(BuildContext context) {
    final mutation = entry.value;
    final id = mutation.entityId == null ? '' : ' #${mutation.entityId}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text('${_label(context.l10n, mutation.entityType)}$id'),
      subtitle: Text(mutation.lastError ?? context.l10n.syncUnknownError),
      trailing: IconButton(
        tooltip: context.l10n.syncDiscard,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => context.read<SyncStatusCubit>().discard(entry.key),
      ),
    );
  }
}
