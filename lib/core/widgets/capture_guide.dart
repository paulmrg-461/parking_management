import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

/// Standard photo angles so the entry and exit sets are comparable. The slot
/// order is fixed; after four corners the guide suggests a damage detail.
enum AngleSlot { frontLeft, frontRight, rearRight, rearLeft, detail }

extension AngleSlotX on AngleSlot {
  String chip(AppLocalizations l10n) => l10n.guideSlotChip(name);
}

/// The slot the next photo should cover, clamped to `detail` once every
/// corner is done.
AngleSlot slotForIndex(int captured) {
  if (captured < 0) {
    return AngleSlot.frontLeft;
  }
  if (captured >= AngleSlot.values.length) {
    return AngleSlot.detail;
  }
  return AngleSlot.values[captured];
}

/// "Siguiente foto: …" plus the standing rules. Pure guidance: it never
/// blocks capture or submission.
class AngleGuideBanner extends StatelessWidget {
  const AngleGuideBanner({super.key, required this.captured});

  final int captured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final slot = slotForIndex(captured);
    return Container(
      key: const Key('guide_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  l10n.guideNextPhoto(slot.name),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                key: const Key('guide_show_illustration'),
                onPressed: () => showAngleIllustration(context),
                child: Text(l10n.guideShowIllustration),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            l10n.guideRules,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Captured slots are checked; the rest invite the operator to shoot them.
class AngleSlotChips extends StatelessWidget {
  const AngleSlotChips({super.key, required this.captured});

  final int captured;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('guide_slots'),
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (var index = 0; index < AngleSlot.values.length; index++)
          Chip(
            key: Key('guide_slot_$index'),
            avatar: index < captured
                ? const Icon(Icons.check, size: 16)
                : null,
            label: Text(AngleSlot.values[index].chip(context.l10n)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

Future<void> showAngleIllustration(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const Dialog(child: _AngleIllustration()),
);

class _AngleIllustration extends StatelessWidget {
  const _AngleIllustration();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('guide_illustration'),
    padding: const EdgeInsets.all(Space.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomPaint(
          size: const Size(280, 160),
          painter: _CarOutline(
            Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          context.l10n.guideRules,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _CarOutline extends CustomPainter {
  _CarOutline(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final body = Path()
      ..moveTo(size.width * .12, size.height * .65)
      ..lineTo(size.width * .25, size.height * .35)
      ..lineTo(size.width * .75, size.height * .35)
      ..lineTo(size.width * .88, size.height * .65)
      ..close();
    canvas.drawPath(body, stroke);

    void marker(Offset center, String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, center);
    }

    marker(Offset(size.width * .10, size.height * .28), '1');
    marker(Offset(size.width * .82, size.height * .28), '2');
    marker(Offset(size.width * .82, size.height * .72), '3');
    marker(Offset(size.width * .10, size.height * .72), '4');
  }

  @override
  bool shouldRepaint(covariant _CarOutline oldDelegate) =>
      oldDelegate.color != color;
}
