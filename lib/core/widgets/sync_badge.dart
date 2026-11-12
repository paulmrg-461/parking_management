import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../sync/pending_mutation.dart';
import '../theme/tokens.dart';
import '../sync/sync_outbox.dart';
import '../sync/sync_status_cubit.dart';
import 'conflict_resolution_dialog.dart';

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

class _SyncDetailsSheet extends StatefulWidget {
  const _SyncDetailsSheet();

  @override
  State<_SyncDetailsSheet> createState() => _SyncDetailsSheetState();
}

class _SyncDetailsSheetState extends State<_SyncDetailsSheet> {
  /// The server version each conflict showed the last time it was opened, so
  /// a record that changed again can say so.
  final Map<int, int> _seenVersions = {};

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
                context.l10n.syncConflictSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final entry in status.conflicts)
                _ConflictTile(
                  entry,
                  onTap: () => _openConflict(context, entry),
                ),
            ],
            for (final entry in status.deadLetters) _DeadLetterTile(entry),
          ],
        ),
      ),
    );
  }

  Future<void> _openConflict(BuildContext context, OutboxEntry entry) async {
    final cubit = context.read<SyncStatusCubit>();
    final version = entry.value.decodeServerRow()?['version'];
    final seen = _seenVersions[entry.key];
    if (version is num) {
      _seenVersions[entry.key] = version.toInt();
    }
    await showDialog<bool>(
      context: context,
      builder: (_) => ConflictResolutionDialog(
        entry: entry,
        apply: cubit.resolve,
        seenVersion: seen,
      ),
    );
    if (mounted) {
      await cubit.load();
    }
  }
}

/// A parked conflict: tapping opens the field-by-field resolution dialog.
class _ConflictTile extends StatelessWidget {
  const _ConflictTile(this.entry, {required this.onTap});

  final OutboxEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mutation = entry.value;
    final id = mutation.entityId == null ? '' : ' #${mutation.entityId}';
    return ListTile(
      key: Key('sync-resolve-${entry.key}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.merge_type),
      title: Text(
        '${_DeadLetterTile._label(context.l10n, mutation.entityType)}$id',
      ),
      subtitle: Text(context.l10n.syncConflictTileSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
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
