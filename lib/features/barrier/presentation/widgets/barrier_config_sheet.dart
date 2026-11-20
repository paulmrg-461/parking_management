import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../application/barrier_cubit.dart';
import '../../domain/commands/barrier_config_update.dart';
import '../../domain/entities/barrier.dart';

Future<void> showBarrierConfigSheet(
  BuildContext context,
  Barrier barrier,
  BarrierCubit cubit,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BarrierConfigSheet(barrier: barrier, cubit: cubit),
  );
}

class _BarrierConfigSheet extends StatefulWidget {
  const _BarrierConfigSheet({required this.barrier, required this.cubit});

  final Barrier barrier;
  final BarrierCubit cubit;

  @override
  State<_BarrierConfigSheet> createState() => _BarrierConfigSheetState();
}

class _BarrierConfigSheetState extends State<_BarrierConfigSheet> {
  late final BarrierConfig _config =
      widget.barrier.config ?? const BarrierConfig();
  late BarrierDirection _direction = _config.direction;
  late String _openOnCheckin = _config.openOnCheckin;
  late String _openOnPaidExit = _config.openOnPaidExit;
  late bool _pass = _config.openForPassEntry;
  late int _hold = _config.openHoldMs;
  late int _maxOpen = _config.maxOpenSeconds;
  late int _postClear = _config.postClearDelayMs;
  late int _ttl = _config.commandTtlSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: ListView(
            children: [
              Text(l10n.barrierConfigTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: Space.sm),
              if (widget.barrier.cameraName case final camera?)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(
                    '${l10n.barrierConfigCamera}: $camera',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SegmentedButton<BarrierDirection>(
                segments: [
                  ButtonSegment(
                    value: BarrierDirection.entry,
                    label: Text(l10n.barrierDirectionEntry),
                  ),
                  ButtonSegment(
                    value: BarrierDirection.exit,
                    label: Text(l10n.barrierDirectionExit),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) =>
                    setState(() => _direction = selection.first),
              ),
              const SizedBox(height: Space.md),
              _ruleField(
                label: l10n.barrierConfigOpenOnCheckin,
                value: _openOnCheckin,
                onChanged: (value) => setState(() => _openOnCheckin = value),
              ),
              const SizedBox(height: Space.sm),
              _ruleField(
                label: l10n.barrierConfigOpenOnPaidExit,
                value: _openOnPaidExit,
                onChanged: (value) => setState(() => _openOnPaidExit = value),
              ),
              SwitchListTile(
                key: const Key('barrier_config_pass'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.barrierConfigPass),
                subtitle: Text(l10n.barrierConfigPassWarning),
                value: _pass,
                onChanged: (value) => setState(() => _pass = value),
              ),
              _Stepper(
                label: l10n.barrierConfigHold,
                value: _hold,
                min: 200,
                max: 30000,
                step: 100,
                onChanged: (value) => setState(() => _hold = value),
              ),
              _Stepper(
                label: l10n.barrierConfigMaxOpen,
                value: _maxOpen,
                min: 5,
                max: 120,
                onChanged: (value) => setState(() => _maxOpen = value),
              ),
              _Stepper(
                label: l10n.barrierConfigPostClear,
                value: _postClear,
                min: 500,
                max: 10000,
                step: 100,
                onChanged: (value) => setState(() => _postClear = value),
              ),
              _Stepper(
                label: l10n.barrierConfigTtl,
                value: _ttl,
                min: 10,
                max: 120,
                onChanged: (value) => setState(() => _ttl = value),
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                key: const Key('barrier_config_save'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.barrierSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final l10n = context.l10n;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(
          value: 'never',
          child: Text(l10n.barrierConfigRuleNever),
        ),
        DropdownMenuItem(
          value: 'lpr_only',
          child: Text(l10n.barrierConfigRuleLpr),
        ),
        DropdownMenuItem(
          value: 'always',
          child: Text(l10n.barrierConfigRuleAlways),
        ),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  void _save() {
    widget.cubit.saveConfig(
      BarrierConfigUpdate(
        deviceId: widget.barrier.deviceId,
        direction: _direction,
        openOnCheckin: _openOnCheckin,
        openOnPaidExit: _openOnPaidExit,
        openForPassEntry: _pass,
        openHoldMs: _hold,
        maxOpenSeconds: _maxOpen,
        postClearDelayMs: _postClear,
        commandTtlSeconds: _ttl,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '−',
          onPressed: value <= min
              ? null
              : () => onChanged(value - step < min ? min : value - step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 64,
          child: Text('$value', textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: '+',
          onPressed: value >= max
              ? null
              : () => onChanged(value + step > max ? max : value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
