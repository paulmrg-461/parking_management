import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

/// Touch keypad for plate entry: cabin tablets may have no physical keyboard,
/// and plates only use A–Z and 0–9. It edits the shared controller so the
/// form's own validation and lookup keep working.
class PlateKeypad extends StatelessWidget {
  const PlateKeypad({
    super.key,
    required this.controller,
    this.maxLength = 20,
    this.onChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  static const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F',
    'G', 'H', 'I', 'J', 'K', 'L',
    'M', 'N', 'O', 'P', 'Q', 'R',
    'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z',
  ];

  void _append(String key) {
    final current = controller.text;
    if (current.length >= maxLength) {
      return;
    }
    final next = '$current$key';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    onChanged?.call(next);
  }

  void _backspace() {
    final current = controller.text;
    if (current.isEmpty) {
      return;
    }
    final next = current.substring(0, current.length - 1);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    onChanged?.call(next);
  }

  void _clear() {
    controller.value = const TextEditingValue(text: '');
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <List<String>>[
      _digits.sublist(0, 6),
      _digits.sublist(6),
      _letters.sublist(0, 6),
      _letters.sublist(6, 12),
      _letters.sublist(12, 18),
      _letters.sublist(18, 24),
      _letters.sublist(24),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              _KeyRow(
                keys: row,
                onKey: _append,
                trailing: row.length == 2
                    ? [
                        _KeyAction(
                          icon: Icons.backspace_outlined,
                          tooltip: l10n.plateKeypadBackspace,
                          onPressed: _backspace,
                        ),
                        _KeyAction(
                          icon: Icons.close,
                          tooltip: l10n.plateKeypadClear,
                          onPressed: _clear,
                        ),
                      ]
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onKey, this.trailing});

  final List<String> keys;
  final ValueChanged<String> onKey;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final key in keys)
        Expanded(
          child: _KeyButton(label: key, onPressed: () => onKey(key)),
        ),
      if (trailing case final actions?) ...[
        const SizedBox(width: Space.xs),
        for (final action in actions) ...[
          Expanded(child: action),
          const SizedBox(width: Space.xs),
        ],
      ],
    ];
    // Pad the shorter rows so every key keeps the same width.
    while (children.length < 7) {
      children.add(const Expanded(child: SizedBox.shrink()));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(children: children),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            textStyle: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _KeyAction extends StatelessWidget {
  const _KeyAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

/// Opens the keypad as a bottom sheet editing [controller].
Future<void> showPlateKeypad(
  BuildContext context, {
  required TextEditingController controller,
  int maxLength = 20,
  ValueChanged<String>? onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => SingleChildScrollView(
    child: PlateKeypad(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
    ),
  ),
);
