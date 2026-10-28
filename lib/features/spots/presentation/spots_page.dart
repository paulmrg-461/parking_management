import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../application/spots_cubit.dart';
import '../domain/entities/parking_spot.dart';

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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(
                  l10n.spotsAdminOnly,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
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
                SpotsStatus.initial || SpotsStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                SpotsStatus.failure => ErrorState(
                  message: context.l10n.failure(state.error!),
                  onRetry: context.read<SpotsCubit>().load,
                ),
                SpotsStatus.loaded => _MapEditor(state: state),
              },
            ),
    );
  }
}

class _MapEditor extends StatelessWidget {
  const _MapEditor({required this.state});

  final SpotsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spots = state.spots;
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
        const _Legend(),
        Expanded(
          child: spots.isEmpty
              ? Center(
                  child: Text(
                    l10n.spotsEmpty,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
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
    final suggestion = 'S${state.spots.length + 1}';
    final draft = await showDialog<_SpotDraft>(
      context: context,
      builder: (_) => _AddSpotDialog(initialCode: suggestion),
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
          width: 76,
          height: 76,
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          decoration: BoxDecoration(
            color: highlighted
                ? scheme.primaryContainer.withValues(alpha: 0.4)
                : null,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              color: highlighted
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: highlighted ? 2 : 1,
            ),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final tint = spot.active ? status.success : scheme.outline;
    return Container(
      decoration: BoxDecoration(
        color: spot.active
            ? status.success.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: tint.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            spot.active
                ? switch (spot.group) {
                    SlotGroup.car => Icons.directions_car,
                    SlotGroup.moto => Icons.two_wheeler,
                    SlotGroup.heavy => Icons.local_shipping,
                  }
                : Icons.build_circle_outlined,
            size: 16,
            color: spot.active ? status.success : scheme.outline,
          ),
          const SizedBox(height: 2),
          Text(
            spot.code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          if (dragging)
            Text(
              context.l10n.spotsDragHere,
              style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _SpotDraft {
  const _SpotDraft({required this.code, required this.group});

  final String code;
  final SlotGroup group;
}

class _AddSpotDialog extends StatefulWidget {
  const _AddSpotDialog({required this.initialCode});

  final String initialCode;

  @override
  State<_AddSpotDialog> createState() => _AddSpotDialogState();
}

class _AddSpotDialogState extends State<_AddSpotDialog> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  SlotGroup _group = SlotGroup.car;

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
  const _GroupField({required this.value, required this.onChanged});

  final SlotGroup value;
  final ValueChanged<SlotGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<SlotGroup>(
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.spotsGroup),
      items: [
        DropdownMenuItem(
          value: SlotGroup.car,
          child: Text(l10n.homeCapacityCars),
        ),
        DropdownMenuItem(
          value: SlotGroup.moto,
          child: Text(l10n.homeCapacityMotos),
        ),
        DropdownMenuItem(
          value: SlotGroup.heavy,
          child: Text(l10n.slotBoardHeavy),
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
