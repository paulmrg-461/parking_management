import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../../home/application/dashboard_cubit.dart';
import '../application/spots_cubit.dart';
import '../domain/entities/parking_spot.dart';
import 'widgets/spot_cell_view.dart';

/// Admin editor for the site's physical map: add bays, drag them around a
/// grid, rename them or take them out of service. The map is configured once;
/// check-in then assigns each car to a bay.
class SpotsPage extends StatefulWidget {
  const SpotsPage({super.key, this.isAdmin = true});

  final bool isAdmin;

  @override
  State<SpotsPage> createState() => _SpotsPageState();
}

class _SpotsPageState extends State<SpotsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<SpotsCubit>().load());
  }

  /// Spots configured in Ajustes (`0` = no limit), read from the shell
  /// dashboard snapshot. The editor may not draw a different number.
  Map<SlotGroup, int> _targets(BuildContext context) {
    try {
      final state = context.watch<DashboardCubit>().state;
      if (state is DashboardLoaded) {
        return {
          SlotGroup.car: state.capacity.carTarget,
          SlotGroup.moto: state.capacity.motoTarget,
        };
      }
    } on ProviderNotFoundException {
      // Isolated tests: no targets, the server still enforces them.
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spotsTitle),
        actions: [
          IconButton(
            tooltip: l10n.homeRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: context.read<SpotsCubit>().load,
          ),
        ],
      ),
      body: !widget.isAdmin
          ? EmptyState(
              icon: Icons.lock_outline,
              title: l10n.spotsTitle,
              message: l10n.spotsAdminOnly,
            )
          : BlocConsumer<SpotsCubit, SpotsState>(
              listenWhen: (previous, current) =>
                  previous.actionError != current.actionError &&
                  current.actionError != null,
              listener: (context, state) {
                final error = state.actionError;
                if (error != null) {
                  showErrorSnack(context, context.l10n.failure(error));
                  context.read<SpotsCubit>().clearActionError();
                }
              },
              builder: (context, state) => switch (state.status) {
                SpotsStatus.initial ||
                SpotsStatus.loading => const SkeletonCardList(itemCount: 3),
                SpotsStatus.failure => ErrorState(
                  message: context.l10n.failure(state.error!),
                  onRetry: context.read<SpotsCubit>().load,
                ),
                SpotsStatus.loaded => _MapEditor(
                  state: state,
                  targets: _targets(context),
                ),
              },
            ),
    );
  }
}

class _MapEditor extends StatelessWidget {
  const _MapEditor({required this.state, this.targets = const {}});

  final SpotsState state;
  final Map<SlotGroup, int> targets;

  int _target(SlotGroup group) => targets[group] ?? 0;

  int _drawn(SlotGroup group) =>
      state.spots.where((spot) => spot.group == group).length;

  bool _canAdd(SlotGroup group) {
    final target = _target(group);
    return target == 0 || _drawn(group) < target;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spots = state.spots;
    for (final group in SlotGroup.values) {
      if (_target(group) > 0 || _drawn(group) > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Keep the cubit enforcement in sync with the configured count.
          if (context.mounted) {
            final cubit = context.read<SpotsCubit>();
            cubit.setTargets({
              for (final entry in targets.entries)
                if (entry.value > 0) entry.key: entry.value,
            });
          }
        });
        break;
      }
    }
    final rows = spots.fold<int>(3, (max, spot) => spot.row + 1 > max ? spot.row + 1 : max) + 1;
    final cols = spots.fold<int>(4, (max, spot) => spot.col + 1 > max ? spot.col + 1 : max) + 1;
    final byCell = {for (final spot in spots) (spot.row, spot.col): spot};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.md,
            Space.md,
            Space.sm,
          ),
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _addSpot(context, state),
                icon: const Icon(Icons.add),
                label: Text(l10n.spotsAdd),
              ),
              Text(
                l10n.spotsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (targets.values.any((value) => value > 0))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.md,
                  runSpacing: Space.xs,
                  children: [
                    for (final group in SlotGroup.values)
                      if (_target(group) > 0 || _drawn(group) > 0)
                        _GroupProgress(
                          group: group,
                          drawn: _drawn(group),
                          target: _target(group),
                        ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  l10n.spotsCapacityHint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const _Legend(),
        Expanded(
          child: spots.isEmpty
              ? EmptyState(
                  icon: Icons.grid_on_outlined,
                  message: l10n.spotsEmpty,
                  action: FilledButton.icon(
                    onPressed: () => _addSpot(context, state),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.spotsAdd),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var row = 0; row < rows; row++)
                          Row(
                            children: [
                              for (var col = 0; col < cols; col++)
                                _CellTarget(
                                  row: row,
                                  col: col,
                                  spot: byCell[(row, col)],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _addSpot(BuildContext context, SpotsState state) async {
    final cubit = context.read<SpotsCubit>();
    final available = {
      for (final group in SlotGroup.values) group: _canAdd(group),
    };
    if (!available.values.any((canAdd) => canAdd)) {
      showErrorSnack(context, context.l10n.errorSpotCapacityReached);
      return;
    }
    final suggestion = 'S${state.spots.length + 1}';
    final draft = await showDialog<_SpotDraft>(
      context: context,
      builder: (_) => _AddSpotDialog(
        initialCode: suggestion,
        available: available,
      ),
    );
    if (draft == null) {
      return;
    }
    await cubit.add(code: draft.code, group: draft.group);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget item(Color color, String label) => Padding(
      padding: const EdgeInsets.only(right: Space.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color, width: 1.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: Space.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Wrap(
        children: [
          item(status.success, l10n.slotFree),
          item(scheme.outline, l10n.slotMaintenance),
        ],
      ),
    );
  }
}

class _CellTarget extends StatelessWidget {
  const _CellTarget({required this.row, required this.col, this.spot});

  final int row;
  final int col;
  final ParkingSpot? spot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<ParkingSpot>(
      onWillAcceptWithDetails: (details) =>
          details.data.row != row || details.data.col != col,
      onAcceptWithDetails: (details) {
        unawaited(context.read<SpotsCubit>().move(details.data, row, col));
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return Container(
          width: SpotCellView.cellSize + SpotCellView.cellGap,
          height: SpotCellView.cellSize + SpotCellView.cellGap,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: highlighted
                ? scheme.primaryContainer.withValues(alpha: 0.4)
                : null,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: highlighted
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: switch (spot) {
            final spot? => LongPressDraggable<ParkingSpot>(
              data: spot,
              feedback: Material(
                color: Colors.transparent,
                child: _SpotCard(spot: spot, dragging: true),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _SpotCard(spot: spot),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: () => _edit(context, spot),
                child: _SpotCard(spot: spot),
              ),
            ),
            _ => Center(
              child: Text(
                '${row + 1}-${col + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          },
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, ParkingSpot spot) {
    final cubit = context.read<SpotsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider<SpotsCubit>.value(
        value: cubit,
        child: _EditSpotSheet(spot: spot),
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, this.dragging = false});

  final ParkingSpot spot;
  final bool dragging;

  @override
  Widget build(BuildContext context) => SpotCellView(
    spot: spot,
    primary: spot.code,
    secondary: !spot.active
        ? context.l10n.slotMaintenanceShort
        : dragging
        ? context.l10n.spotsDragHere
        : null,
  );
}

class _SpotDraft {
  const _SpotDraft({required this.code, required this.group});

  final String code;
  final SlotGroup group;
}

class _AddSpotDialog extends StatefulWidget {
  const _AddSpotDialog({required this.initialCode, this.available = const {}});

  final String initialCode;

  /// Groups with room left (false = already at the configured count).
  final Map<SlotGroup, bool> available;

  @override
  State<_AddSpotDialog> createState() => _AddSpotDialogState();
}

class _AddSpotDialogState extends State<_AddSpotDialog> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  late SlotGroup _group = [
    for (final group in SlotGroup.values)
      if (widget.available[group] != false) group,
  ].firstOrNull ?? SlotGroup.car;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.spotsAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('spot_code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l10n.spotsCode),
          ),
          const SizedBox(height: Space.md),
          _GroupField(
            value: _group,
            onChanged: (value) => setState(() => _group = value),
            enabled: widget.available,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final code = _code.text.trim().toUpperCase();
            if (code.isEmpty) {
              return;
            }
            Navigator.of(context).pop(_SpotDraft(code: code, group: _group));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _EditSpotSheet extends StatefulWidget {
  const _EditSpotSheet({required this.spot});

  final ParkingSpot spot;

  @override
  State<_EditSpotSheet> createState() => _EditSpotSheetState();
}

class _EditSpotSheetState extends State<_EditSpotSheet> {
  late final TextEditingController _code = TextEditingController(
    text: widget.spot.code,
  );
  late SlotGroup _group = widget.spot.group;
  late bool _active = widget.spot.active;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      return;
    }
    await context.read<SpotsCubit>().update(
      widget.spot.copyWith(code: code, group: _group, active: _active),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.spotsDeleteTitle,
        body: l10n.spotsDeleteBody(widget.spot.code),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final removed = await context.read<SpotsCubit>().remove(widget.spot);
    if (removed && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.spotLabel(widget.spot.code)),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('spot_edit_code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l10n.spotsCode),
            ),
            const SizedBox(height: Space.md),
            _GroupField(
              value: _group,
              onChanged: (value) => setState(() => _group = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: Text(l10n.spotsActive),
              subtitle: Text(l10n.spotsActiveHint),
            ),
            const SizedBox(height: Space.sm),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.spotsDelete),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupField extends StatelessWidget {
  const _GroupField({
    required this.value,
    required this.onChanged,
    this.enabled = const {},
  });

  final SlotGroup value;
  final ValueChanged<SlotGroup> onChanged;

  /// A false entry disables that group (already at its configured count).
  final Map<SlotGroup, bool> enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<SlotGroup>(
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.spotsGroup),
      items: [
        for (final (group, label) in [
          (SlotGroup.car, l10n.homeCapacityCars),
          (SlotGroup.moto, l10n.homeCapacityMotos),
          (SlotGroup.heavy, l10n.slotBoardHeavy),
        ])
          DropdownMenuItem(
            value: group,
            enabled: enabled[group] != false,
            child: Text(label),
          ),
      ],
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}

class _GroupProgress extends StatelessWidget {
  const _GroupProgress({
    required this.group,
    required this.drawn,
    required this.target,
  });

  final SlotGroup group;
  final int drawn;
  final int target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (group) {
      SlotGroup.car => l10n.homeCapacityCars,
      SlotGroup.moto => l10n.homeCapacityMotos,
      SlotGroup.heavy => l10n.slotBoardHeavy,
    };
    final mismatch = target > 0 && drawn != target;
    final detail = target > 0
        ? l10n.spotsGroupCount(drawn, target)
        : '$drawn';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          switch (group) {
            SlotGroup.car => Icons.directions_car,
            SlotGroup.moto => Icons.two_wheeler,
            SlotGroup.heavy => Icons.local_shipping,
          },
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: Space.xs),
        Text(
          '$label $detail',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: mismatch ? scheme.error : scheme.onSurface,
            fontWeight: mismatch ? FontWeight.w700 : null,
          ),
        ),
        if (mismatch) ...[
          const SizedBox(width: Space.xs),
          Text(
            drawn < target
                ? l10n.spotsRemaining(target - drawn)
                : l10n.spotsExcess(drawn - target),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
