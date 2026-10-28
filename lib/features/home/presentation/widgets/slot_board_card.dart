import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/elapsed.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/submission_feedback.dart';
import '../../../auth/application/auth_cubit.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../check_out/domain/entities/check_out_preview.dart';
import '../../../check_out/domain/entities/slot_board.dart';
import '../../../spots/domain/entities/parking_spot.dart';
import '../../../spots/presentation/widgets/spot_cell_view.dart';
import '../../../check_out/presentation/widgets/fare_breakdown_view.dart';
import '../../../reservations/domain/entities/reservation.dart';
import '../../../reservations/domain/repositories/reservation_repository.dart';
import '../../application/dashboard_cubit.dart';

/// What the operator is looking at: everything, one vehicle group, or only the
/// promised spaces.
enum SlotFilter { all, car, moto, holds }

/// Visual board of the site's spaces: free cells, occupied vehicles (plate and
/// elapsed time) and active holds. Tapping a cell opens its details with the
/// live fare and a direct check-out.
class SlotBoardCard extends StatefulWidget {
  const SlotBoardCard({super.key, this.reservations});

  /// Lets an admin release a hold from the board. Optional in tests.
  final ReservationRepository? reservations;

  @override
  State<SlotBoardCard> createState() => _SlotBoardCardState();
}

class _SlotBoardCardState extends State<SlotBoardCard> {
  SlotFilter _filter = SlotFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<DashboardCubit, DashboardState>(
      buildWhen: (previous, current) =>
          previous is! DashboardLoaded ||
          current is! DashboardLoaded ||
          previous.slotBoard != current.slotBoard,
      builder: (context, state) => switch (state) {
        DashboardLoaded(:final slotBoard) => _Board(
          board: slotBoard,
          filter: _filter,
          onFilter: (filter) => setState(() => _filter = filter),
          reservations: widget.reservations,
        ),
        DashboardFailure(:final failure) => Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.slotBoardTitle, style: _titleStyle(context)),
                const SizedBox(height: Space.sm),
                ErrorState(
                  message: l10n.failure(failure),
                  onRetry: context.read<DashboardCubit>().load,
                ),
              ],
            ),
          ),
        ),
        _ => const _SlotBoardSkeleton(),
      },
    );
  }
}

TextStyle? _titleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium;

int _capacityOf(SlotBoard board, SlotGroup group) => switch (group) {
  SlotGroup.car => board.carCapacity,
  SlotGroup.moto => board.motoCapacity,
  SlotGroup.heavy => 0,
};

int _free(SlotBoard board, SlotGroup group) {
  final capacity = _capacityOf(board, group);
  if (capacity == 0) {
    return 0;
  }
  final used =
      board.sessionsIn(group).length +
      board.holdsIn(group).length +
      board.outOfServiceIn(group);
  return (capacity - used).clamp(0, capacity);
}

String _groupLabel(AppLocalizations l10n, SlotGroup group) => switch (group) {
  SlotGroup.car => l10n.homeCapacityCars,
  SlotGroup.moto => l10n.homeCapacityMotos,
  SlotGroup.heavy => l10n.slotBoardHeavy,
};

IconData _groupIcon(SlotGroup group) => switch (group) {
  SlotGroup.car => Icons.directions_car,
  SlotGroup.moto => Icons.two_wheeler,
  SlotGroup.heavy => Icons.local_shipping,
};

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.filter,
    required this.onFilter,
    this.reservations,
  });

  final SlotBoard board;
  final SlotFilter filter;
  final ValueChanged<SlotFilter> onFilter;
  final ReservationRepository? reservations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (board.isEmpty) {
      return _EmptyBoard(configure: _isAdmin(context));
    }
    final free = board.carCapacity > 0 || board.motoCapacity > 0
        ? _free(board, SlotGroup.car) + _free(board, SlotGroup.moto)
        : 0;
    final groups = [
      for (final group in SlotGroup.values)
        if (_showsGroup(group)) group,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 20),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.slotBoardTitle,
                      style: _titleStyle(context),
                    ),
                  ),
                ),
                if (board.carCapacity > 0 || board.motoCapacity > 0)
                  StatusChip(
                    label: l10n.slotBoardFree(free),
                    tone: StatusTone.success,
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            _Filters(board: board, selected: filter, onSelected: onFilter),
            if (filter == SlotFilter.holds) ...[
              if (board.holds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Text(
                    l10n.slotBoardNoHolds,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                _HoldsStrip(board: board, reservations: reservations),
            ] else if (board.hasMap) ...[
              _SpotMap(
                board: board,
                filter: filter,
                reservations: reservations,
              ),
              if (board.holds.isNotEmpty)
                _HoldsStrip(board: board, reservations: reservations),
              if (board.unassignedSessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    board.unassignedSessions.length == 1
                        ? l10n.slotNoSpotAssignedOne
                        : l10n.slotNoSpotAssigned(
                            board.unassignedSessions.length,
                          ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ] else
              for (final group in groups)
                _GroupSection(
                  board: board,
                  group: group,
                  onlyHolds: false,
                  reservations: reservations,
                ),
          ],
        ),
      ),
    );
  }

  /// Filters are inclusive: the hold filter still needs some content, while
  /// the vehicle filters only show their own group.
  bool _showsGroup(SlotGroup group) {
    final hasSession = board.sessionsIn(group).isNotEmpty;
    final hasHold = board.holdsIn(group).isNotEmpty;
    return switch (filter) {
          SlotFilter.all => true,
          SlotFilter.car => group == SlotGroup.car,
          SlotFilter.moto => group == SlotGroup.moto,
          SlotFilter.holds => hasHold,
        } &&
        (hasSession || hasHold || _capacityOf(board, group) > 0);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.board,
    required this.selected,
    required this.onSelected,
  });

  final SlotBoard board;
  final SlotFilter selected;
  final ValueChanged<SlotFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        _FilterChip(
          icon: Icons.apps,
          label: l10n.slotBoardAll,
          selected: selected == SlotFilter.all,
          onSelected: () => onSelected(SlotFilter.all),
        ),
        if (_capacityOf(board, SlotGroup.car) > 0 ||
            board.sessionsIn(SlotGroup.car).isNotEmpty)
          _FilterChip(
            icon: Icons.directions_car,
            label: l10n.slotBoardCars,
            selected: selected == SlotFilter.car,
            onSelected: () => onSelected(SlotFilter.car),
          ),
        if (_capacityOf(board, SlotGroup.moto) > 0 ||
            board.sessionsIn(SlotGroup.moto).isNotEmpty)
          _FilterChip(
            icon: Icons.two_wheeler,
            label: l10n.slotBoardMotos,
            selected: selected == SlotFilter.moto,
            onSelected: () => onSelected(SlotFilter.moto),
          ),
        if (board.holds.isNotEmpty)
          _FilterChip(
            icon: Icons.event_available,
            label: l10n.slotBoardHolds,
            selected: selected == SlotFilter.holds,
            onSelected: () => onSelected(SlotFilter.holds),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    // 48 dp tall tap targets for cabin tablets.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.board,
    required this.group,
    required this.onlyHolds,
    this.reservations,
  });

  final SlotBoard board;
  final SlotGroup group;
  final bool onlyHolds;
  final ReservationRepository? reservations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final capacity = _capacityOf(board, group);
    final sessions = board.sessionsIn(group);
    final holds = board.holdsIn(group);
    final free = _free(board, group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
          child: Row(
            children: [
              Icon(
                _groupIcon(group),
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  _groupLabel(l10n, group),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                capacity > 0 ? '$free / $capacity' : '${sessions.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        _CellsGrid(
          sessions: sessions,
          holds: holds,
          group: group,
          capacity: capacity,
          outOfService: board.outOfServiceIn(group),
          onlyHolds: onlyHolds,
          reservations: reservations,
        ),
      ],
    );
  }
}

class _CellsGrid extends StatelessWidget {
  const _CellsGrid({
    required this.sessions,
    required this.holds,
    required this.group,
    required this.capacity,
    required this.outOfService,
    required this.onlyHolds,
    this.reservations,
  });

  final List<SlotSession> sessions;
  final List<SlotHold> holds;
  final SlotGroup group;
  final int capacity;
  final int outOfService;
  final bool onlyHolds;
  final ReservationRepository? reservations;

  static const _target = 76.0;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    if (onlyHolds) {
      cells.addAll(
        holds.map((hold) => _SlotCell.hold(hold, reservations: reservations)),
      );
    } else {
      cells.addAll(sessions.map(_SlotCell.session));
      cells.addAll(
        holds.map((hold) => _SlotCell.hold(hold, reservations: reservations)),
      );
      // Heavy vehicles have no configured capacity: one cell per car.
      final maintenance = capacity == 0 ? 0 : outOfService.clamp(0, capacity);
      for (var i = 0; i < maintenance; i++) {
        cells.add(_SlotCell.maintenance(group));
      }
      final freeCells = capacity == 0
          ? 0
          : (capacity - sessions.length - holds.length - maintenance).clamp(
              0,
              capacity,
            );
      for (var i = 0; i < freeCells; i++) {
        cells.add(_SlotCell.free(group, index: i + 1));
      }
    }
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / _target).floor().clamp(2, 12);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.xs,
          crossAxisSpacing: Space.xs,
          childAspectRatio: 1,
          children: cells,
        );
      },
    );
  }
}

/// The site's physical map: one cell per bay, positioned by the admin. Free
/// bays show their code, occupied ones the plate and elapsed time, and
/// out-of-service bays the striped maintenance state.
class _SpotMap extends StatelessWidget {
  const _SpotMap({
    required this.board,
    required this.filter,
    this.reservations,
  });

  final SlotBoard board;
  final SlotFilter filter;
  final ReservationRepository? reservations;

  bool _shows(ParkingSpot spot) => switch (filter) {
    SlotFilter.all => true,
    SlotFilter.car => spot.group == SlotGroup.car,
    SlotFilter.moto => spot.group == SlotGroup.moto,
    SlotFilter.holds => false,
  };

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final spot in board.spots)
        if (_shows(spot)) spot,
    ];
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }
    final rows = spots.map((spot) => spot.row).reduce((a, b) => a > b ? a : b) + 1;
    final cols = spots.map((spot) => spot.col).reduce((a, b) => a > b ? a : b) + 1;
    final byCell = {
      for (final spot in spots) '${spot.row}:${spot.col}': spot,
    };
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The dashboard scales the whole map uniformly to fit the card (it
          // never distorts individual cells) and scrolls only when the phone
          // is narrower than the minimum readable cell.
          final available = constraints.maxWidth;
          final rawSize = available.isFinite
              ? (available - SpotCellView.cellGap * (cols - 1)) / cols
              : SpotCellView.cellSize;
          final size = rawSize
              .clamp(SpotCellView.minBoardSize, SpotCellView.cellSize)
              .toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var row = 0; row < rows; row++)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpotCellView.cellGap,
                    ),
                    child: Row(
                      children: [
                        for (var col = 0; col < cols; col++)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: SpotCellView.cellGap,
                            ),
                            child: switch (byCell['$row:$col']) {
                              final spot? => _SpotCell(
                                spot: spot,
                                session: board.sessionAt(spot),
                                reservations: reservations,
                                size: size,
                              ),
                              _ => _EmptySpotCell(
                                key: ValueKey('empty_${row}_$col'),
                                size: size,
                              ),
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptySpotCell extends StatelessWidget {
  const _EmptySpotCell({super.key, this.size = SpotCellView.cellSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _SpotCell extends StatelessWidget {
  const _SpotCell({
    required this.spot,
    this.session,
    this.reservations,
    this.size = SpotCellView.cellSize,
  });

  final ParkingSpot spot;
  final SlotSession? session;
  final ReservationRepository? reservations;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = spot.active;
    final occupied = session != null;

    final content = SpotCellView(
      spot: spot,
      size: size,
      primary: occupied ? session!.plate : spot.code,
      secondary: !active
          ? l10n.slotMaintenanceShort
          : occupied
          ? elapsedLabel(l10n, session!.entryTime)
          : l10n.slotFree,
    );

    final semantics = !active
        ? '${l10n.slotMaintenance} ${spot.code}'
        : occupied
        ? '${l10n.slotOccupied} ${session!.plate}, ${spot.code}, '
              '${elapsedLabel(l10n, session!.entryTime)}'
        : '${l10n.slotFree} ${spot.code}';
    return Semantics(
      label: semantics,
      button: occupied,
      excludeSemantics: true,
      child: Tooltip(
        message: semantics,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: occupied
                ? () => _showSession(context, session!, spotCode: spot.code)
                : null,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Holds have no bay yet: they are promised spots, shown as a compact strip.
class _HoldsStrip extends StatelessWidget {
  const _HoldsStrip({required this.board, this.reservations});

  final SlotBoard board;
  final ReservationRepository? reservations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final hold in board.holds)
            ActionChip(
              avatar: const Icon(Icons.event_available, size: 18),
              label: Text(
                '${hold.plate} · ${Formatters.time(hold.until.toLocal())}',
              ),
              onPressed: () => _showHold(context, hold, reservations),
            ),
          if (board.holds.isEmpty)
            Text(l10n.slotBoardNoHolds),
        ],
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell._({
    required this.group,
    this.session,
    this.hold,
    this.index,
    this.maintenance = false,
    this.reservations,
  });

  factory _SlotCell.session(SlotSession session) =>
      _SlotCell._(group: session.group, session: session);

  factory _SlotCell.hold(
    SlotHold hold, {
    ReservationRepository? reservations,
  }) => _SlotCell._(group: hold.group, hold: hold, reservations: reservations);

  factory _SlotCell.free(SlotGroup group, {required int index}) =>
      _SlotCell._(group: group, index: index);

  factory _SlotCell.maintenance(SlotGroup group) =>
      _SlotCell._(group: group, maintenance: true);

  final SlotGroup group;
  final SlotSession? session;
  final SlotHold? hold;
  final int? index;
  final bool maintenance;
  final ReservationRepository? reservations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final occupied = session != null;
    final held = hold != null;
    final tint = switch ((occupied, held)) {
      (true, _) => scheme.primary,
      (_, true) => status.pending,
      _ => maintenance ? scheme.outline : status.success,
    };
    final label = occupied
        ? l10n.slotOccupied
        : held
        ? l10n.slotReserved
        : maintenance
        ? l10n.slotMaintenance
        : l10n.slotFree;
    final detail = session?.plate ?? hold?.plate;
    final caption = occupied
        ? elapsedLabel(l10n, session!.entryTime)
        : held
        ? Formatters.time(hold!.until.toLocal())
        : '${index ?? ''}';

    final content = Container(
      decoration: BoxDecoration(
        color: maintenance
            ? scheme.surfaceContainerHighest
            : Color.alphaBlend(
                tint.withValues(alpha: occupied ? 0.10 : 0.14),
                scheme.surface,
              ),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(
          color: occupied
              ? scheme.outlineVariant
              : maintenance
              ? scheme.outline
              : tint.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: CustomPaint(
        painter: maintenance ? _StripesPainter(scheme.outline) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              maintenance ? Icons.build_circle_outlined : _groupIcon(group),
              size: 18,
              color: occupied ? scheme.onSurfaceVariant : tint,
            ),
            const SizedBox(height: 2),
            Text(
              detail ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontFamily: detail == null ? null : 'monospace',
                fontWeight: detail == null ? FontWeight.w500 : FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Text(
              detail == null
                  ? (maintenance ? l10n.slotMaintenanceShort : '')
                  : caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                height: 1.1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    final semantics = switch ((occupied, held)) {
      (true, _) =>
        '$label ${session!.plate}, '
            '${elapsedLabel(l10n, session!.entryTime)}',
      (_, true) =>
        '$label ${hold!.plate}, '
            '${l10n.reservationUntil(Formatters.time(hold!.until.toLocal()))}',
      _ when maintenance => '$label ${_groupLabel(l10n, group)}',
      _ => '$label ${_groupLabel(l10n, group)} ${index ?? ''}',
    };
    final cell = Semantics(
      label: semantics,
      button: occupied || held,
      excludeSemantics: true,
      child: Tooltip(
        message: semantics,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: occupied
                ? () => _showSession(context, session!)
                : held
                ? () => _showHold(context, hold!, reservations)
                : null,
            child: content,
          ),
        ),
      ),
    );
    return cell;
  }
}

Future<void> _showSession(
  BuildContext context,
  SlotSession session, {
  String? spotCode,
}) async {
  final cubit = context.read<DashboardCubit>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SessionSheet(
      session: session,
      cubit: cubit,
      spotCode: spotCode,
    ),
  );
}

Future<void> _showHold(
  BuildContext context,
  SlotHold hold,
  ReservationRepository? reservations,
) async {
  final cubit = context.read<DashboardCubit>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        _HoldSheet(hold: hold, cubit: cubit, reservations: reservations),
  );
}

/// Hold details. Admins can release the hold when the customer does not
/// arrive; operators only see the promise.
class _HoldSheet extends StatefulWidget {
  const _HoldSheet({
    required this.hold,
    required this.cubit,
    this.reservations,
  });

  final SlotHold hold;
  final DashboardCubit cubit;
  final ReservationRepository? reservations;

  @override
  State<_HoldSheet> createState() => _HoldSheetState();
}

class _HoldSheetState extends State<_HoldSheet> {
  bool _busy = false;

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final repository = widget.reservations;
    if (repository == null) {
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.reservationCancelTitle,
        body: l10n.reservationCancelBody(widget.hold.plate),
        confirmLabel: l10n.reservationCancel,
        destructive: true,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final active = await repository.listActive();
      final match = _match(active);
      if (match != null) {
        await repository.cancel(match.id);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      showInfoSnack(context, l10n.reservationCancelled);
      unawaited(widget.cubit.load());
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnack(context, context.l10n.failure(failure));
      }
    }
  }

  /// The board payload has no reservation id, so the plate + expiry identify
  /// it in the active list (expiry to the minute, server clock).
  Reservation? _match(List<Reservation> active) {
    final plate = widget.hold.plate.toUpperCase();
    for (final reservation in active) {
      if (reservation.plate.toUpperCase() != plate) {
        continue;
      }
      final delta = reservation.reservedUntil.difference(widget.hold.until);
      if (delta.inSeconds.abs() <= 60) {
        return reservation;
      }
    }
    for (final reservation in active) {
      if (reservation.plate.toUpperCase() == plate) {
        return reservation;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final admin = _isAdmin(context);
    final canCancel = admin && widget.reservations != null && !_busy;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(text: widget.hold.plate),
            const SizedBox(height: Space.xs),
            Text(
              l10n.reservationUntil(
                Formatters.dateTime(widget.hold.until.toLocal()),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Space.md),
            StatusChip(
              label: l10n.slotReserved,
              tone: StatusTone.warning,
              icon: Icons.event_available,
            ),
            if (canCancel) ...[
              const SizedBox(height: Space.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.event_busy),
                  label: Text(l10n.reservationCancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontFamily: 'monospace'),
    ),
  );
}

/// Session details with a one-second clock (elapsed time) and a fare preview
/// refreshed once a minute; the amount is always the server's.
class _SessionSheet extends StatefulWidget {
  const _SessionSheet({
    required this.session,
    required this.cubit,
    this.spotCode,
  });

  final SlotSession session;
  final DashboardCubit cubit;
  final String? spotCode;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  Timer? _ticker;
  int _ticks = 0;
  CheckOutPreview? _preview;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _ticks++);
      if (_ticks % 60 == 0) {
        unawaited(_loadPreview());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final preview = await widget.cubit.preview(widget.session.sessionId);
    if (!mounted) {
      return;
    }
    setState(() {
      _preview = preview;
      _failed = preview == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    final preview = _preview;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(text: session.plate),
            const SizedBox(height: Space.xs),
            Text(
              l10n.sessionEntry(Formatters.dateTime(session.entryTime)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                if (widget.spotCode case final code?)
                  StatusChip(
                    label: l10n.spotLabel(code),
                    tone: StatusTone.neutral,
                    icon: Icons.grid_view_rounded,
                  ),
                StatusChip(
                  label: elapsedLabel(l10n, session.entryTime),
                  tone: StatusTone.neutral,
                  icon: Icons.timer_outlined,
                ),
                if (session.hasPass)
                  StatusChip(
                    label: l10n.paymentMonthlyPass,
                    tone: StatusTone.success,
                    icon: Icons.card_membership,
                  ),
                if (session.leftKeys)
                  StatusChip(
                    label: l10n.checkInLeftKeysShort,
                    tone: StatusTone.warning,
                    icon: Icons.key_outlined,
                  ),
                if (session.photoCount > 0)
                  StatusChip(
                    label: l10n.sessionPhotos(session.photoCount),
                    tone: StatusTone.neutral,
                    icon: Icons.photo_camera_outlined,
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            if (preview != null)
              FareBreakdownView(preview: preview, showTime: false)
            else if (_failed)
              Text(
                l10n.slotEstimateUnavailable,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              const LinearProgressIndicator(),
            const SizedBox(height: Space.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(
                    '/check-out?scan=${Uri.encodeQueryComponent(session.plate)}',
                  );
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n.navCheckOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.configure});

  final bool configure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.slotBoardTitle, style: _titleStyle(context)),
            const SizedBox(height: Space.sm),
            EmptyState(
              message: l10n.slotBoardEmpty,
              icon: Icons.grid_view_outlined,
              action: configure
                  ? FilledButton.icon(
                      onPressed: () => context.go('/spots'),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: Text(l10n.spotsTitle),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotBoardSkeleton extends StatelessWidget {
  const _SlotBoardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 16,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (var i = 0; i < 12; i++)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _isAdmin(BuildContext context) {
  try {
    final auth = context.read<AuthCubit>();
    return switch (auth.state) {
      AuthAuthenticated(:final session) => session.user.role == UserRole.admin,
      _ => false,
    };
  } on ProviderNotFoundException {
    return false;
  }
}

/// Diagonal hatching for out-of-service cells, readable in both themes
/// without hiding the label (state is not colour-only).
class _StripesPainter extends CustomPainter {
  const _StripesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    const step = 8.0;
    for (var offset = -size.height; offset < size.width; offset += step) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      oldDelegate.color != color;
}
