import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dialer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp_launcher.dart';
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
import '../../settings/domain/whatsapp_url.dart';
import '../application/reservations_cubit.dart';
import '../domain/entities/reservation.dart';
import 'reservation_dialog.dart';
import 'reservations_csv.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key, this.onCheckIn});

  /// Sends the operator to check-in with the plate prefilled. Injectable so a
  /// widget test can record it without a router.
  final Future<void> Function(BuildContext context, String plate)? onCheckIn;

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
            ReservationsInitial() ||
            ReservationsLoading() => const SkeletonList(),
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

Future<void> _checkInWithPlate(BuildContext context, String plate) =>
    context.push('/check-in?plate=${Uri.encodeQueryComponent(plate)}');

class _List extends StatefulWidget {
  const _List({
    required this.loaded,
    required this.onAdd,
    required this.onCheckIn,
  });

  final ReservationsLoaded loaded;
  final VoidCallback onAdd;
  final Future<void> Function(BuildContext context, String plate) onCheckIn;

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  String _query = '';
  bool _onlyExpiring = false;
  bool _onlyPublic = false;

  List<Reservation> get _all => sortedByExpiry(widget.loaded.reservations);

  List<Reservation> _visible(List<Reservation> all) {
    final needle = _query.trim().toLowerCase();
    final now = DateTime.now();
    return [
      for (final reservation in all)
        if ((needle.isEmpty || _matches(reservation, needle)) &&
            (!_onlyExpiring || reservation.expiresSoon(now: now)) &&
            (!_onlyPublic || reservation.isPublic))
          reservation,
    ];
  }

  bool _matches(Reservation reservation, String needle) {
    // A short number can be the reservation code printed on the confirmation.
    if (RegExp(r'^\d{1,6}$').hasMatch(needle) &&
        reservation.id.toString() == needle) {
      return true;
    }
    return reservation.plate.toLowerCase().contains(needle) ||
        (reservation.customerName ?? '').toLowerCase().contains(needle) ||
        (reservation.customerPhone ?? '').contains(needle);
  }

  bool get _filtered =>
      _query.trim().isNotEmpty || _onlyExpiring || _onlyPublic;

  /// Reception prints the shift list: the visible rows (filters included) as
  /// CSV, with the code the customer shows.
  Future<void> _copyCsv(BuildContext context, List<Reservation> rows) async {
    await Clipboard.setData(ClipboardData(text: reservationsCsv(rows)));
    if (context.mounted) {
      showInfoSnack(context, context.l10n.reservationsCsvCopied);
    }
  }

  void _clear() => setState(() {
    _query = '';
    _onlyExpiring = false;
    _onlyPublic = false;
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
                    constraints: const BoxConstraints(
                      minHeight: Layout.minTouch,
                    ),
                    child: FilterChip(
                      selected: _onlyExpiring,
                      showCheckmark: false,
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(l10n.reservationsOnlyExpiring),
                      onSelected: (value) =>
                          setState(() => _onlyExpiring = value),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: Layout.minTouch,
                    ),
                    child: OutlinedButton.icon(
                      key: const Key('reservations_csv'),
                      onPressed: visible.isEmpty
                          ? null
                          : () => _copyCsv(context, visible),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(l10n.reservationsCopyCsv),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: Layout.minTouch,
                    ),
                    child: FilterChip(
                      selected: _onlyPublic,
                      showCheckmark: false,
                      avatar: const Icon(Icons.public, size: 18),
                      label: Text(l10n.reservationsOnlyPublic),
                      onSelected: (value) =>
                          setState(() => _onlyPublic = value),
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

/// Name + phone of a public booking, with the one-tap actions the front desk
/// needs: call or WhatsApp the customer without copying the number.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = reservation.customerPhone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    return Row(
      children: [
        Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            reservation.contactLine ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (hasPhone) ...[
          IconButton(
            tooltip: l10n.reservationCall,
            icon: const Icon(Icons.call_outlined),
            onPressed: () => openDialer(phone),
          ),
          IconButton(
            tooltip: l10n.reservationWhatsApp,
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => openWhatsapp(
              context,
              whatsappUrl(
                phone,
                text: l10n.reservationWhatsAppMessage(reservation.plate),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation, required this.onCheckIn});

  final Reservation reservation;
  final Future<void> Function(BuildContext context, String plate) onCheckIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final soon = reservation.expiresSoon(now: now);
    final inGrace = reservation.inGrace;
    final notes = reservation.notes;
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.sm,
          Space.sm,
          Space.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: soon
                    ? scheme.tertiaryContainer
                    : scheme.primaryContainer,
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
                      if (reservation.isPublic) ...[
                        StatusChip(
                          key: const Key('reservation_public'),
                          label: l10n.reservationWeb,
                          tone: StatusTone.success,
                          icon: Icons.public,
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                      if (reservation.categoryName.isNotEmpty)
                        StatusChip(
                          label: reservation.categoryName,
                          tone: StatusTone.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  // The code the customer shows (#7) sits first: reception can
                  // match it against the web confirmation at a glance.
                  Text(
                    '#${reservation.id} · '
                    '${l10n.reservationUntil(Formatters.dateTime(reservation.reservedUntil.toLocal()))}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (reservation.hasContact) ...[
                    const SizedBox(height: Space.xs),
                    _ContactLine(reservation: reservation),
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (inGrace) ...[
                    const SizedBox(height: Space.xs),
                    StatusChip(
                      key: const Key('reservation_in_grace'),
                      label: l10n.reservationInGrace,
                      tone: StatusTone.warning,
                      icon: Icons.hourglass_bottom,
                    ),
                  ] else if (soon) ...[
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
                  onPressed: () async {
                    // Coming back from check-in, the hold is gone (`used`):
                    // reload so the board is not stale.
                    await onCheckIn(context, reservation.plate);
                    if (context.mounted) {
                      unawaited(context.read<ReservationsCubit>().load());
                    }
                  },
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
