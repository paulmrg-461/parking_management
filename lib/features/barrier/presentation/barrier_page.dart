import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/barrier_cubit.dart';
import '../domain/commands/open_barrier_request.dart';
import '../domain/entities/barrier.dart';
import '../domain/entities/barrier_command.dart';
import 'widgets/barrier_card.dart';
import 'widgets/barrier_config_sheet.dart';
import 'widgets/barrier_history_sheet.dart';
import 'widgets/open_barrier_dialog.dart';

/// `/barrier`: the lot's barriers, their status and the manual opening with a
/// mandatory reason. Admins also get the configuration.
class BarrierPage extends StatefulWidget {
  const BarrierPage({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  State<BarrierPage> createState() => _BarrierPageState();
}

class _BarrierPageState extends State<BarrierPage> {
  late final BarrierCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<BarrierCubit>();
    _cubit.load();
  }

  Future<void> _open(Barrier barrier) async {
    if (!barrier.online) {
      showErrorSnack(context, context.l10n.barrierNeedsConnection);
      return;
    }
    final reason = await showOpenBarrierDialog(context, barrier);
    if (reason == null || !mounted) return;
    await _cubit.openManually(
      OpenBarrierRequest(deviceId: barrier.deviceId, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.barrierTitle)),
      body: BlocConsumer<BarrierCubit, BarrierState>(
        listenWhen: (_, current) =>
            _submissionOf(current) is SubmissionFailed,
        listener: (context, state) {
          final submission = _submissionOf(state);
          if (submission is SubmissionFailed) {
            showErrorSnack(
              context,
              context.l10n.errorText(submission.message, submission.failure),
            );
          }
        },
        builder: (context, state) => switch (state) {
          BarrierLoading() => const _BarrierSkeleton(),
          BarrierFailure(:final failure) => ErrorState(
            message: l10n.failure(failure),
            onRetry: () => _cubit.load(),
          ),
          BarrierEmpty() => EmptyState(
            icon: Icons.garage_outlined,
            title: l10n.barrierEmptyTitle,
            message: l10n.barrierEmptyBody,
            action: FilledButton.icon(
              onPressed: () => context.go('/devices'),
              icon: const Icon(Icons.devices_other_outlined),
              label: Text(l10n.gateGoToDevices),
            ),
          ),
          BarrierLoaded(:final barriers, :final tracking) => RefreshIndicator(
            onRefresh: _cubit.load,
            child: ListView(
              padding: const EdgeInsets.all(Space.md),
              children: [
                if (tracking != null) _TrackingBanner(command: tracking),
                for (final barrier in barriers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: BarrierCard(
                      barrier: barrier,
                      onOpen: () => _open(barrier),
                      onHistory: () =>
                          showBarrierHistorySheet(context, barrier, _cubit),
                      onConfig: widget.isAdmin
                          ? () => showBarrierConfigSheet(context, barrier, _cubit)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        },
      ),
    );
  }

  Submission _submissionOf(BarrierState state) => switch (state) {
    BarrierEmpty(:final submission) => submission,
    BarrierLoaded(:final submission) => submission,
    _ => const SubmissionIdle(),
  };
}

class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.command});

  final BarrierCommand command;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (text, tone) = switch (command.status) {
      BarrierCommandStatus.queued ||
      BarrierCommandStatus.delivered => (l10n.barrierOpening, scheme.primary),
      BarrierCommandStatus.executed => (l10n.barrierOpened, scheme.primary),
      _ => (
        l10n.barrierOpenFailed(command.status.name),
        scheme.error,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('barrier_tracking'),
        margin: const EdgeInsets.only(bottom: Space.sm),
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            Icon(
              command.status.succeeded
                  ? Icons.check_circle_outline
                  : command.status.isTerminal
                  ? Icons.error_outline
                  : Icons.hourglass_top_outlined,
              color: tone,
            ),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: TextStyle(color: tone))),
          ],
        ),
      ),
    );
  }
}

class _BarrierSkeleton extends StatelessWidget {
  const _BarrierSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.separated(
        padding: const EdgeInsets.all(Space.md),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (_, _) => const Card(
          child: Padding(
            padding: EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 24),
                SizedBox(height: Space.sm),
                SkeletonBox(width: 100),
                SizedBox(height: Space.md),
                SkeletonBox(width: 130, height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
