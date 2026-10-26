import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../application/lots_cubit.dart';
import '../domain/entities/parking_lot.dart';

/// Compact active-site chip with a switcher (only for members of more than one
/// site). It lives inside the page content, not as a strip above the app bar.
class LotSwitcher extends StatelessWidget {
  const LotSwitcher({super.key});

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
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const Icon(Icons.location_on_outlined, size: 18),
        label: Text(active.name),
        tooltip: context.l10n.lotSwitchTooltip(active.name),
        onPressed: () => _open(context, state.lots, active),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.xs,
                Space.md,
                Space.sm,
              ),
              child: Text(
                context.l10n.lotSwitchTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
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
