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
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/search_field.dart';
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
              onAdd: _add,
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

class _List extends StatefulWidget {
  const _List({
    required this.loaded,
    required this.onAdd,
    required this.onCheckIn,
  });

  final ReservationsLoaded loaded;
  final VoidCallback onAdd;
  final void Function(BuildContext context, String plate) onCheckIn;

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  String _query = '';
  bool _onlyExpiring = false;

  List<Reservation> get _all => sortedByExpiry(widget.loaded.reservations);

  List<Reservation> _visible(List<Reservation> all) {
    final needle = _query.trim().toLowerCase();
    final now = DateTime.now();
    return [
      for (final reservation in all)
        if ((needle.isEmpty ||
                reservation.plate.toLowerCase().contains(needle)) &&
            (!_onlyExpiring || reservation.expiresSoon(now: now)))
          reservation,
    ];
  }

  bool get _filtered => _query.trim().isNotEmpty || _onlyExpiring;

  void _clear() => setState(() {
    _query = '';
    _onlyExpiring = false;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = _all;
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: l10n.reservationsEmpty,
        message: l10n.reservationsEmptyHint,
        action: FilledButton.icon(
          onPressed: widget.onAdd,
          icon: const Icon(Icons.add),
          label: Text(l10n.reservationAdd),
        ),
      );
    }
    final now = DateTime.now();
    final expiring = all.where((item) => item.expiresSoon(now: now)).length;
    final visible = _visible(all);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.event_available_outlined,
                        label: l10n.reservationsActive,
                        value: '${all.length}',
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.schedule,
                        label: l10n.reservationsExpiring,
                        value: '$expiring',
                        tone: expiring > 0
                            ? MetricTone.warning
                            : MetricTone.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              FilterBar(
                summary: l10n.reservationsCount(visible.length),
                onClear: _filtered ? _clear : null,
                clearLabel: l10n.actionClearFilters,
                children: [
                  SizedBox(
                    width: 240,
                    child: SearchField(
                      label: l10n.reservationsSearchLabel,
                      hint: l10n.reservationsSearchHint,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Layout.minTouch),
                    child: FilterChip(
                      selected: _onlyExpiring,
                      showCheckmark: false,
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(l10n.reservationsOnlyExpiring),
                      onSelected: (value) =>
                          setState(() => _onlyExpiring = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  message: l10n.reservationsFilteredEmpty,
                  action: FilledButton.tonalIcon(
                    onPressed: _clear,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(l10n.actionClearFilters),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: Space.xl),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => StaggeredListItem(
                    key: ValueKey(visible[index].id),
                    index: index,
                    child: _ReservationTile(
                      reservation: visible[index],
                      onCheckIn: widget.onCheckIn,
                    ),
                  ),
                ),
        ),
      ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final soon = reservation.expiresSoon(now: now);
    final notes = reservation.notes;
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: soon ? scheme.tertiaryContainer : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(
                soon ? Icons.schedule : Icons.event_available_outlined,
                color: soon
                    ? scheme.onTertiaryContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: PlateText(reservation.plate)),
                      if (reservation.categoryName.isNotEmpty)
                        StatusChip(
                          label: reservation.categoryName,
                          tone: StatusTone.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.reservationUntil(
                      Formatters.dateTime(reservation.reservedUntil.toLocal()),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (soon) ...[
                    const SizedBox(height: Space.xs),
                    StatusChip(
                      label: l10n.reservationExpiresIn(
                        Formatters.duration(
                          l10n,
                          reservation.reservedUntil.difference(now),
                        ),
                      ),
                      tone: StatusTone.warning,
                      icon: Icons.schedule,
                    ),
                  ],
                ],
              ),
            ),
            Column(
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
