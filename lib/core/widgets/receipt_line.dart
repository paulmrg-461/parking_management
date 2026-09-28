import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "Label ........ value" row read as one phrase by screen readers.
class ReceiptLine extends StatelessWidget {
  const ReceiptLine({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final Widget value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: emphasized ? textTheme.titleMedium : textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: Space.md),
            DefaultTextStyle.merge(
              style: emphasized
                  ? textTheme.headlineSmall
                  : textTheme.bodyLarge,
              child: value,
            ),
          ],
        ),
      ),
    );
  }
}
