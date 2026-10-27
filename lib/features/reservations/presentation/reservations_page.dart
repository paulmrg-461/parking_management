import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered_list_item.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../application/reservations_cubit.dart';
import '../domain/entities/reservation.dart';
import 'reservation_dialog.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key, this.onCheckIn});

  /// Sends the operator to check-in with the plate prefilled. Injectable so a
  /// widget test can record it without a router.
  final void Function(BuildContext context, String plate)? onCheckIn;

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<ReservationsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SubmissionListener<ReservationsCubit, ReservationsState>(
      submissionOf: _submissionOf,
      onSuccess: (context, _) => _confirmAction(context),
      child: ListPageScaffold(
        title: l10n.reservationsTitle,
        addTooltip: l10n.reservationAdd,
        onAdd: _add,
        onRefresh: context.read<ReservationsCubit>().load,
        body: BlocBuilder<ReservationsCubit, ReservationsState>(
          builder: (context, state) => switch (state) {
            ReservationsInitial() || ReservationsLoading() =>
              const SkeletonList(),
            ReservationsFailure(:final message) => ErrorState(
              message: message,
              onRetry: context.read<ReservationsCubit>().load,
            ),
            final ReservationsLoaded loaded => _List(
              loaded: loaded,
              onCheckIn: widget.onCheckIn ?? _checkInWithPlate,
            ),
          },
        ),
      ),
    );
  }

  static Submission? _submissionOf(ReservationsState state) =>
      state is ReservationsLoaded ? state.submission : null;

  void _confirmAction(BuildContext context) {
    final state = context.read<ReservationsCubit>().state;
    final action = state is ReservationsLoaded ? state.lastAction : null;
    final l10n = context.l10n;
    final message = switch (action) {
      ReservationsAction.created => l10n.reservationCreated,
      ReservationsAction.cancelled => l10n.reservationCancelled,
      null => null,
    };
    if (message == null) {
      return;
    }
    SemanticsService.announce(message, Directionality.of(context));
    showInfoSnack(context, message);
  }

  Future<void> _add() async {
    final cubit = context.read<ReservationsCubit>();
    final state = cubit.state;
    if (state is! ReservationsLoaded) {
      return;
    }
    final draft = await showDialog<ReservationDraft>(
      context: context,
      builder: (_) => ReservationDialog(categories: state.categories),
    );
    if (draft != null) {
      await cubit.create(
        plate: draft.plate,
        categoryId: draft.categoryId,
        until: draft.until,
        notes: draft.notes,
      );
    }
  }
}

void _checkInWithPlate(BuildContext context, String plate) => context.push(
  '/check-in?plate=${Uri.encodeQueryComponent(plate)}',
);

class _List extends StatelessWidget {
  const _List({required this.loaded, required this.onCheckIn});

  final ReservationsLoaded loaded;
  final void Function(BuildContext context, String plate) onCheckIn;

  @override
  Widget build(BuildContext context) {
    if (loaded.reservations.isEmpty) {
      return EmptyState(
        message: context.l10n.reservationsEmpty,
        icon: Icons.event_available_outlined,
      );
    }
    final reservations = sortedByExpiry(loaded.reservations);
    return ListView.builder(
      itemCount: reservations.length,
      itemBuilder: (context, index) => StaggeredListItem(
        key: ValueKey(reservations[index].id),
        index: index,
        child: _ReservationTile(
          reservation: reservations[index],
          onCheckIn: onCheckIn,
        ),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation, required this.onCheckIn});

  final Reservation reservation;
  final void Function(BuildContext context, String plate) onCheckIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      child: ListTile(
        title: Text(reservation.plate),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (reservation.categoryName.isNotEmpty)
                  reservation.categoryName,
                l10n.reservationUntil(
                  Formatters.dateTime(reservation.reservedUntil.toLocal()),
                ),
                if (reservation.notes != null && reservation.notes!.isNotEmpty)
                  reservation.notes!,
              ].join(' · '),
            ),
            if (reservation.expiresSoon(now: now))
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: StatusChip(
                  label: l10n.reservationExpiresIn(
                    Formatters.duration(
                      l10n,
                      reservation.reservedUntil.difference(now),
                    ),
                  ),
                  tone: StatusTone.warning,
                  icon: Icons.schedule,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.reservationCheckIn,
              icon: const Icon(Icons.login),
              onPressed: () => onCheckIn(context, reservation.plate),
            ),
            IconButton(
              tooltip: l10n.reservationCancel,
              icon: const Icon(Icons.close),
              onPressed: () => _cancel(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.reservationCancelTitle),
        content: Text(context.l10n.reservationCancelBody(reservation.plate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.reservationCancel),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ReservationsCubit>().cancel(reservation.id);
    }
  }
}
