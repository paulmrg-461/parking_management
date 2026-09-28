import 'package:flutter/material.dart';

enum PlateSize { medium, large }

/// A licence plate in a monospace, tabular style so characters line up and
/// `0`/`O` read apart. Screen readers spell it character by character.
class PlateText extends StatelessWidget {
  const PlateText(this.plate, {super.key, this.size = PlateSize.medium});

  final String plate;
  final PlateSize size;

  static TextStyle styleFor(BuildContext context, PlateSize size) {
    final textTheme = Theme.of(context).textTheme;
    final base = size == PlateSize.large
        ? textTheme.headlineMedium
        : textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['RobotoMono', 'Courier New', 'monospace'],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    );
  }

  @override
  Widget build(BuildContext context) => Text(
    plate,
    style: styleFor(context, size),
    semanticsLabel: plate.split('').join(' '),
  );
}
