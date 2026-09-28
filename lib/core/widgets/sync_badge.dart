import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
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
        return IconButton(
          tooltip: _tooltip(context.l10n, status),
          onPressed: () => _showDetails(context, cubit),
          icon: Badge(
            label: Text('${status.total}'),
            backgroundColor: hasErrors
                ? Theme.of(context).colorScheme.error
                : null,
            child: Icon(hasErrors ? Icons.sync_problem : Icons.sync),
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
    return errors == 0 ? base : l10n.syncPendingWithErrors(base, errors);
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
            Text(context.l10n.syncQueued(status.pendingCount)),
            for (final entry in status.deadLetters) _DeadLetterTile(entry),
          ],
        ),
      ),
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
