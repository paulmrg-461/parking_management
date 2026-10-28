import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/cop_formatter.dart';

/// COP notes and coins, biggest first: the way a cashier empties the drawer.
const cashDenominations = <int>[
  100000,
  50000,
  20000,
  10000,
  5000,
  2000,
  1000,
  500,
  200,
  100,
];

/// Counts the drawer by denomination and returns the total (null on cancel).
Future<int?> showCashCountSheet(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const CashCountSheet(),
    );

class CashCountSheet extends StatefulWidget {
  const CashCountSheet({super.key});

  @override
  State<CashCountSheet> createState() => _CashCountSheetState();
}

class _CashCountSheetState extends State<CashCountSheet> {
  late final List<int> _denominations = Money.currency.denominations;
  late final Map<int, TextEditingController> _quantities = {
    for (final denomination in _denominations)
      denomination: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _quantity(int denomination) =>
      int.tryParse(_quantities[denomination]!.text.trim()) ?? 0;

  int get _total {
    var total = 0;
    for (final denomination in _denominations) {
      total += denomination * _quantity(denomination);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = _total;
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.cashCountTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Text(
                  CopFormatter.format(total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final denomination in _denominations)
                      _DenominationRow(
                        denomination: denomination,
                        controller: _quantities[denomination]!,
                        onChanged: (_) => setState(() {}),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: total <= 0
                    ? null
                    : () => Navigator.of(context).pop(total),
                child: Text(
                  l10n.cashCountUse(CopFormatter.format(total)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenominationRow extends StatelessWidget {
  const _DenominationRow({
    required this.denomination,
    required this.controller,
    required this.onChanged,
  });

  final int denomination;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              CopFormatter.format(denomination),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              key: Key('cash_qty_$denomination'),
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              CopFormatter.format(denomination * (int.tryParse(controller.text) ?? 0)),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
