import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../check_out/domain/entities/check_out_preview.dart';
import '../domain/repositories/loyalty_repository.dart';

/// What the check-out dialog needs to apply or skip a reward.
class LoyaltyDeskOptions {
  const LoyaltyDeskOptions({required this.choose});

  /// Stores the choice and returns the refreshed preview.
  final Future<CheckOutPreview> Function(LoyaltyChoice choice) choose;
}

/// Reward block of the settlement dialog (reads `quote.reward`).
class DeskLoyaltySection extends StatefulWidget {
  const DeskLoyaltySection({
    super.key,
    required this.options,
    required this.preview,
    required this.onChanged,
  });

  final LoyaltyDeskOptions options;
  final CheckOutPreview? preview;
  final ValueChanged<CheckOutPreview> onChanged;

  @override
  State<DeskLoyaltySection> createState() => _DeskLoyaltySectionState();
}

class _DeskLoyaltySectionState extends State<DeskLoyaltySection> {
  bool _busy = false;

  Map<String, Object?>? get _reward {
    final reward = widget.preview?.quote?.reward;
    if (reward == null || reward['available'] != true) {
      return null;
    }
    return reward;
  }

  Future<void> _choose(LoyaltyChoice choice) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final preview = await widget.options.choose(choice);
      widget.onChanged(preview);
    } on Failure catch (failure) {
      if (mounted) {
        showErrorSnack(context, context.l10n.failure(failure));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = _reward;
    if (reward == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final applied = reward['applied'] == true;
    final reason = reward['reason'] as String?;
    final progress = reward['progress'] is Map
        ? Map<String, dynamic>.from(reward['progress'] as Map)
        : const <String, dynamic>{};
    final visits = (progress['visits'] as num?)?.toInt() ?? 0;
    final required = (progress['required'] as num?)?.toInt() ?? 0;

    return Padding(
      key: const Key('desk_loyalty_section'),
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (required > 0)
            Text(
              l10n.loyaltyVisitOf(visits + 1, required),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (applied)
            Row(
              children: [
                Expanded(child: Text(l10n.loyaltyRewardLine)),
                TextButton(
                  key: const Key('loyalty_dont_use'),
                  onPressed: _busy ? null : () => _choose(LoyaltyChoice.skip),
                  child: Text(l10n.loyaltyDontUseNow),
                ),
              ],
            )
          else if (reason == 'operator_choice_pending')
            SwitchListTile(
              key: const Key('loyalty_use_reward'),
              contentPadding: EdgeInsets.zero,
              value: false,
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value) {
                        _choose(LoyaltyChoice.redeem);
                      }
                    },
              title: Text(l10n.loyaltyUseReward),
            )
          else
            Text(
              reason == 'skipped'
                  ? l10n.loyaltyDontUseNow
                  : l10n.loyaltyRewardAvailable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
