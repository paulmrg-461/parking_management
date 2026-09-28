import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// A COP amount formatted for es_CO (`$150.000`).
class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style});

  final int amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    Formatters.money(amount),
    style: (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
