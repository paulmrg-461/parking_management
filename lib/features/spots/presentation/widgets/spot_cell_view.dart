import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../check_out/domain/entities/slot_board.dart';
import '../../domain/entities/parking_spot.dart';

/// The bay drawing shared by the map editor and the dashboard board, so the
/// board is an exact copy of the configured layout: same size, colors, stripes
/// and group icon.
class SpotCellView extends StatelessWidget {
  const SpotCellView({
    super.key,
    required this.spot,
    this.primary,
    this.secondary,
    this.size = cellSize,
    this.highlighted = false,
    this.occupied = false,
  });

  /// Edge of one bay, in logical pixels.
  static const cellSize = 72.0;

  /// Gap between bays, identical in the editor and the board.
  static const cellGap = 6.0;

  /// Smallest bay the dashboard draws when it scales the map to fit.
  static const minBoardSize = 56.0;

  final ParkingSpot spot;

  /// Big text (plate when occupied, else the bay code).
  final String? primary;

  /// Small text (elapsed time, "Libre", "Mant."…).
  final String? secondary;
  final double size;
  final bool highlighted;

  /// A car is inside: the bay is blue (primary) instead of green, so free and
  /// occupied bays are easy to tell apart.
  final bool occupied;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final active = spot.active;
    final tint = !active
        ? scheme.outline
        : occupied
        ? scheme.primary
        : status.success;
    final scale = size / cellSize;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : !active
            ? scheme.surfaceContainerHighest
            : Color.alphaBlend(
                tint.withValues(alpha: occupied ? 0.18 : 0.14),
                scheme.surface,
              ),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(
          color: highlighted
              ? scheme.primary
              : active
              ? tint.withValues(alpha: 0.7)
              : scheme.outline,
          width: highlighted ? 2 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: CustomPaint(
        painter: !active ? _StripesPainter(scheme.outline) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              !active ? Icons.build_circle_outlined : _groupIcon(spot.group),
              size: (16 * scale).clamp(10.0, 16.0),
              color: active ? tint : scheme.outline,
            ),
            const SizedBox(height: 2),
            Text(
              primary ?? spot.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (10 * scale).clamp(7.0, 10.0),
                height: 1.1,
                fontFamily: primary != null && primary != spot.code
                    ? 'monospace'
                    : null,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (secondary case final text?)
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: (8 * scale).clamp(6.0, 8.0),
                  height: 1.1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _groupIcon(SlotGroup group) => switch (group) {
  SlotGroup.car => Icons.directions_car,
  SlotGroup.moto => Icons.two_wheeler,
  SlotGroup.heavy => Icons.local_shipping,
};

/// Diagonal hatching for out-of-service bays; the label stays readable.
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
