import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/lpr_inbox_cubit.dart';
import '../domain/commands/confirm_lpr_entry.dart';
import '../domain/entities/lpr_event.dart';
import 'widgets/lpr_confirm_dialog.dart';
import 'widgets/lpr_event_card.dart';

/// `/gate`: the pending plate reads, oldest decision first. Operators and
/// admins see it; confirming is a normal check-in performed by the signed-in
/// operator.
class GatePage extends StatefulWidget {
  const GatePage({super.key, this.online});

  /// Test seam for the connectivity check.
  final Future<bool> Function()? online;

  @override
  State<GatePage> createState() => _GatePageState();
}

class _GatePageState extends State<GatePage> {
  String _lastAction = '';
  late final LprInboxCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<LprInboxCubit>();
    _cubit.load();
    _cubit.startPolling();
  }

  @override
  void dispose() {
    _cubit.stopPolling();
    super.dispose();
  }

  Future<bool> _isOnline() {
    final check = widget.online ??
        () => serviceLocator<ConnectivityService>().isOnline();
    return check();
  }

  Future<void> _confirm(LprEvent event) async {
    if (!await _isOnline()) {
      if (mounted) showErrorSnack(context, context.l10n.gateNeedsConnection);
      return;
    }
    final plate = await showLprConfirmDialog(context, event);
    if (plate == null || !mounted) return;
    _lastAction = 'confirm';
    await context.read<LprInboxCubit>().confirm(
      ConfirmLprEntry(
        eventId: event.id,
        plate: plate == event.plate ? null : plate,
      ),
    );
  }

  Future<void> _dismiss(LprEvent event) async {
    _lastAction = 'dismiss';
    await context.read<LprInboxCubit>().dismiss(event.id);
  }

  void _checkOut(LprEvent event) {
    context.go('/check-out?scan=${event.plate}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gateTitle)),
      body: BlocConsumer<LprInboxCubit, LprInboxState>(
        listenWhen: (previous, current) =>
            _submissionOf(current) is! SubmissionIdle,
        listener: (context, state) {
          final submission = _submissionOf(state);
          if (submission is SubmissionFailed) {
            showErrorSnack(
              context,
              context.l10n.errorText(submission.message, submission.failure),
            );
          } else if (submission is SubmissionSucceeded) {
            showInfoSnack(
              context,
              _lastAction == 'dismiss'
                  ? l10n.gateDismissed
                  : l10n.gateConfirmed,
            );
          }
        },
        builder: (context, state) => switch (state) {
          LprInboxLoading() => const _GateSkeleton(),
          LprInboxFailure(:final failure) => ErrorState(
            message: l10n.failure(failure),
            onRetry: () => context.read<LprInboxCubit>().load(),
          ),
          LprInboxEmpty(:final submission) => _GateEmpty(submission: submission),
          LprInboxLoaded(:final events, :final submission) => _GateList(
            events: events,
            busy: submission.isInProgress,
            onRefresh: () => context.read<LprInboxCubit>().load(),
            onConfirm: _confirm,
            onDismiss: _dismiss,
            onCheckOut: _checkOut,
          ),
        },
      ),
    );
  }

  Submission _submissionOf(LprInboxState state) => switch (state) {
    LprInboxEmpty(:final submission) => submission,
    LprInboxLoaded(:final submission) => submission,
    _ => const SubmissionIdle(),
  };
}

class _GateEmpty extends StatelessWidget {
  const _GateEmpty({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: Icons.videocam_off_outlined,
      title: l10n.gateEmptyTitle,
      message: l10n.gateEmptyBody,
      action: FilledButton.icon(
        onPressed: () => context.go('/check-in'),
        icon: const Icon(Icons.login),
        label: Text(l10n.gateGoToCheckIn),
      ),
    );
  }
}

class _GateList extends StatelessWidget {
  const _GateList({
    required this.events,
    required this.busy,
    required this.onRefresh,
    required this.onConfirm,
    required this.onDismiss,
    required this.onCheckOut,
  });

  final List<LprEvent> events;
  final bool busy;
  final Future<void> Function() onRefresh;
  final void Function(LprEvent) onConfirm;
  final void Function(LprEvent) onDismiss;
  final void Function(LprEvent) onCheckOut;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(Space.md),
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (context, index) {
          final event = events[index];
          final exitUnpaid =
              !event.isEntry && event.reason == LprEventReason.exitUnpaid;
          return LprEventCard(
            event: event,
            onConfirm: event.isEntry && !busy ? () => onConfirm(event) : null,
            onDismiss: busy ? null : () => onDismiss(event),
            onCheckOut: exitUnpaid && !busy ? () => onCheckOut(event) : null,
          );
        },
      ),
    );
  }
}

class _GateSkeleton extends StatelessWidget {
  const _GateSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.separated(
        padding: const EdgeInsets.all(Space.md),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (_, _) => const Card(
          child: Padding(
            padding: EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 28),
                SizedBox(height: Space.sm),
                SkeletonBox(width: 120),
                SizedBox(height: Space.xs),
                SkeletonBox(width: 90),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
