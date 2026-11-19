import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/price_quote_cubit.dart';
import '../domain/entities/price_quote.dart';

/// Check-in price chip: the rate an entry would pay right now.
class PriceQuoteChip extends StatelessWidget {
  const PriceQuoteChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    try {
      context.read<PriceQuoteCubit>();
    } on ProviderNotFoundException {
      // Isolated pages (tests, login) have no chip.
      return const SizedBox.shrink();
    }
    return BlocBuilder<PriceQuoteCubit, PriceQuoteState>(
      builder: (context, state) => switch (state) {
        PriceQuoteHidden(:final offline) => offline
            ? Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  l10n.priceQuoteOffline,
                  style: theme.textTheme.bodySmall,
                ),
              )
            : const SizedBox.shrink(),
        PriceQuoteLoading() => const SizedBox(
          height: 28,
          child: LinearProgressIndicator(),
        ),
        PriceQuoteFailure() => const SizedBox.shrink(),
        PriceQuoteReady(:final quote) => Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Semantics(
            label: l10n.priceQuoteNow(
              Money.formatAs('COP', quote.hourlyCurrent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.priceQuoteNow(
                        Money.formatAs('COP', quote.hourlyCurrent),
                      ),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (quote.tier != PriceTier.base)
                      StatusChip(
                        key: const Key('price_quote_tier'),
                        label: quote.tier == PriceTier.higher
                            ? l10n.priceQuoteHigher
                            : l10n.priceQuoteLower,
                        tone: quote.tier == PriceTier.higher
                            ? StatusTone.warning
                            : StatusTone.success,
                      ),
                  ],
                ),
                if (quote.tier != PriceTier.base)
                  Text(
                    l10n.priceQuoteUsually(
                      Money.formatAs('COP', quote.hourlyBase),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
