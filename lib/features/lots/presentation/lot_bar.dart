import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../application/lots_cubit.dart';
import '../domain/entities/parking_lot.dart';

/// Compact active-lot indicator with a switcher. Rendered only when the user
/// belongs to more than one site.
class LotBar extends StatelessWidget {
  const LotBar({super.key});

  @override
  Widget build(BuildContext context) {
    final LotsCubit cubit;
    try {
      cubit = context.watch<LotsCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final state = cubit.state;
    if (state is! LotsLoaded || !state.canSwitch) {
      return const SizedBox.shrink();
    }
    final active = state.active;
    if (active == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _open(context, state.lots, active),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  active.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                context.l10n.lotSwitch,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    List<ParkingLot> lots,
    ParkingLot active,
  ) async {
    final cubit = context.read<LotsCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final lot in lots)
              ListTile(
                leading: Icon(
                  lot.id == active.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(lot.name),
                subtitle: Text(lot.code),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  cubit.select(lot.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}
