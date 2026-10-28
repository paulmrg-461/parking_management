import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../check_out/domain/entities/slot_board.dart';
import '../../domain/entities/parking_spot.dart';
import 'spot_cell_view.dart';

/// The configured map, drawn in the check-in form so the operator picks a bay
/// by its real position (the same layout as the dashboard and the editor).
/// "Automatic" keeps the server default: the first free bay.
class SpotPicker extends StatelessWidget {
  const SpotPicker({
    super.key,
    required this.spots,
    required this.sessions,
    required this.selectedId,
    required this.onSelected,
  });

  /// Bays of the vehicle's group (all states, ordered by row/col).
  final List<ParkingSpot> spots;
  final List<SlotSession> sessions;

  /// Selected bay (`null` = automatic).
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final occupied = {
      for (final session in sessions) ?session.spotId: session,
    };
    final free = [
      for (final spot in spots)
        if (spot.active && !occupied.containsKey(spot.id)) spot,
    ];
    final rows =
        spots.map((spot) => spot.row).reduce((a, b) => a > b ? a : b) + 1;
    final cols =
        spots.map((spot) => spot.col).reduce((a, b) => a > b ? a : b) + 1;
    final byCell = {for (final spot in spots) (spot.row, spot.col): spot};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(l10n.checkInSpotTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ChoiceChip(
            label: Text(l10n.checkInSpotAuto),
            selected: selectedId == null,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onSelected(null),
          ),
        ),
        if (selectedId case final id?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.spotLabel(
                spots.firstWhere((spot) => spot.id == id).code,
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final raw = available.isFinite
                ? (available - _gap * (cols - 1)) / cols
                : SpotCellView.cellSize;
            final size = raw.clamp(44.0, 62.0).toDouble();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var row = 0; row < rows; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: Row(
                        children: [
                          for (var col = 0; col < cols; col++)
                            Padding(
                              padding: const EdgeInsets.only(right: _gap),
                              child: switch (byCell[(row, col)]) {
                                final spot? => _PickerCell(
                                  spot: spot,
                                  session: occupied[spot.id],
                                  selected: selectedId == spot.id,
                                  size: size,
                                  onTap: spot.active && !occupied.containsKey(spot.id)
                                      ? () => onSelected(spot.id)
                                      : null,
                                ),
                                _ => Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(Radii.sm),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
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
        if (free.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.checkInSpotNone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.spot,
    this.session,
    required this.selected,
    required this.size,
    this.onTap,
  });

  final ParkingSpot spot;
  final SlotSession? session;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final occupied = session != null;
    final cell = SpotCellView(
      spot: spot,
      size: size,
      highlighted: selected,
      primary: occupied ? session!.plate : spot.code,
      secondary: !spot.active
          ? l10n.slotMaintenanceShort
          : occupied
          ? l10n.slotOccupied
          : l10n.slotFree,
    );
    final semantics = !spot.active
        ? '${l10n.slotMaintenance} ${spot.code}'
        : occupied
        ? '${l10n.slotOccupied} ${session!.plate}, ${spot.code}'
        : '${l10n.slotFree} ${spot.code}';
    return Semantics(
      label: semantics,
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: cell,
        ),
      ),
    );
  }
}
