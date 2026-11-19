import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/loyalty_status_cubit.dart';
import '../domain/entities/loyalty_status.dart';

/// Check-in chip: "Visita 4 de 5" and the reward badge. A missing or failed
/// read never blocks the form.
class LoyaltyProgressChip extends StatelessWidget {
  const LoyaltyProgressChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoyaltyStatusCubit, LoyaltyStatusState>(
      builder: (context, state) => switch (state) {
        LoyaltyStatusIdle() => const SizedBox.shrink(),
        LoyaltyStatusLoading() => const Padding(
          padding: EdgeInsets.only(top: Space.sm),
          child: SkeletonBox(width: 180, height: 20),
        ),
        LoyaltyStatusFailure(:final message, :final failure) => Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  context.l10n.errorText(message, failure),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                key: const Key('loyalty_chip_retry'),
                tooltip: context.l10n.actionRetry,
                onPressed: () =>
                    context.read<LoyaltyStatusCubit>().retry(),
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
        ),
        LoyaltyStatusReady(:final status) => _Ready(status: status),
      },
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.status});

  final LoyaltyStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      key: const Key('loyalty_progress_chip'),
      padding: const EdgeInsets.only(top: Space.xs),
      child: Semantics(
        liveRegion: true,
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.loyalty_outlined,
                  size: 18,
                  color: StatusColors.of(context).success,
                ),
                const SizedBox(width: Space.xs),
                Text(
                  status.earnsRewardNow
                      ? l10n.loyaltyRewardEarned
                      : l10n.loyaltyVisitOf(status.nextVisit, status.required),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (status.hasReward)
              StatusChip(
                key: const Key('loyalty_reward_badge'),
                label: l10n.loyaltyRewardAvailable,
                tone: StatusTone.success,
              ),
          ],
        ),
      ),
    );
  }
}
