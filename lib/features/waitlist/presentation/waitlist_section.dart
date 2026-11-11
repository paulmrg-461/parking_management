import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/user.dart';
import '../application/waitlist_cubit.dart';
import '../domain/entities/waitlist_entry.dart';
import 'public_waitlist_card.dart' show formatTime;
import 'waitlist_settings_dialog.dart';

/// "Lista de espera" section of the reservations board: who is queuing today,
/// who already has an offer and the button to give them the space.
class WaitlistSection extends StatelessWidget {
  const WaitlistSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WaitlistCubit, WaitlistState>(
      builder: (context, state) => switch (state) {
        WaitlistInitial() => const SizedBox.shrink(),
        WaitlistLoading() => const _SkeletonRows(),
        WaitlistFailure(:final failure) => ErrorState(
          message: failure == null
              ? context.l10n.errorUnknown
              : context.l10n.failure(failure),
          onRetry: context.read<WaitlistCubit>().load,
        ),
        final WaitlistLoaded loaded => _section(context, loaded),
      },
    );
  }

  Widget _section(BuildContext context, WaitlistLoaded loaded) {
    final l10n = context.l10n;
    final admin = _isAdmin(context);
    final settings = loaded.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.hourglass_top_outlined,
          title: l10n.waitlistDeskTitle,
          subtitle: settings == null
              ? null
              : settings.enabled
              ? l10n.waitlistWaitingCount(loaded.entries.length)
              : l10n.errorWaitlistDisabled,
          action: admin
              ? IconButton(
                  key: const Key('waitlist-settings'),
                  tooltip: l10n.waitlistSettingsTitle,
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openSettings(context, loaded.settings),
                )
              : null,
        ),
        const SizedBox(height: Space.sm),
        if (loaded.submission case SubmissionFailed(:final failure?))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(
              context.l10n.failure(failure),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (loaded.isEmpty)
          EmptyState(
            icon: Icons.hourglass_empty,
            title: l10n.waitlistDeskEmptyTitle,
            message: l10n.waitlistDeskEmptyHint,
          )
        else
          for (final entry in loaded.entries)
            _WaitlistTile(entry: entry, submitting: loaded.submission.isInProgress),
      ],
    );
  }

  Future<void> _openSettings(
    BuildContext context,
    dynamic settings,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => WaitlistSettingsDialog(initial: settings),
    );
    if (saved == true && context.mounted) {
      await context.read<WaitlistCubit>().load();
    }
  }
}

class _WaitlistTile extends StatelessWidget {
  const _WaitlistTile({required this.entry, required this.submitting});

  final WaitlistEntry entry;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      key: Key('waitlist-entry-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text('${entry.position}'),
      ),
      title: Text(entry.plate),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry.contactLine} · ${entry.categoryName}'),
          if (entry.isOffered && entry.offerUntil != null) ...[
            Text(l10n.waitlistDeskOffered(formatTime(entry.offerUntil!))),
            Text(
              l10n.waitlistDeskCallCustomer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      isThreeLine: entry.isOffered,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.isOffered) ...[
            StatusChip(label: l10n.waitlistOfferChip, tone: StatusTone.pending),
            const SizedBox(width: Space.xs),
            FilledButton(
              key: Key('waitlist-claim-${entry.id}'),
              onPressed: submitting
                  ? null
                  : () => context.read<WaitlistCubit>().claim(entry.id),
              child: Text(l10n.waitlistDeskClaim),
            ),
          ],
          IconButton(
            key: Key('waitlist-remove-${entry.id}'),
            tooltip: l10n.waitlistDeskRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: submitting ? null : () => _remove(context),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.waitlistDeskRemove,
        body: l10n.waitlistDeskRemoveBody(entry.plate),
        confirmLabel: l10n.waitlistDeskRemove,
        destructive: true,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<WaitlistCubit>().remove(entry.id);
    }
  }
}

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Space.sm),
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
          ),
      ],
    );
  }
}

bool _isAdmin(BuildContext context) {
  try {
    return switch (context.read<AuthCubit>().state) {
      AuthAuthenticated(:final session) => session.user.role == UserRole.admin,
      _ => false,
    };
  } on ProviderNotFoundException {
    return false;
  }
}
