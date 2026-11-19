import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../../../core/widgets/plate_text.dart';

/// Signed progress correction. Returns `(delta, reason)` or null.
Future<({int delta, String reason})?> showLoyaltyAdjustDialog(
  BuildContext context, {
  required String plate,
  required int progress,
  required int required,
}) => showDialog<({int delta, String reason})>(
  context: context,
  builder: (_) => _LoyaltyAdjustDialog(
    plate: plate,
    progress: progress,
    required: required,
  ),
);

class _LoyaltyAdjustDialog extends StatefulWidget {
  const _LoyaltyAdjustDialog({
    required this.plate,
    required this.progress,
    required this.required,
  });

  final String plate;
  final int progress;
  final int required;

  @override
  State<_LoyaltyAdjustDialog> createState() => _LoyaltyAdjustDialogState();
}

class _LoyaltyAdjustDialogState extends State<_LoyaltyAdjustDialog> {
  final _delta = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _delta.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final delta = int.tryParse(_delta.text.trim());
    final reason = _reason.text.trim();
    if (delta == null || delta == 0 || delta < -50 || delta > 50) {
      setState(() => _error = l10n.errorLoyaltyAdjustRange);
      return;
    }
    final next = widget.progress + delta;
    if (next < 0 || next > widget.required - 1) {
      setState(() => _error = l10n.errorLoyaltyAdjustRange);
      return;
    }
    if (reason.length < 3 || reason.length > 200) {
      setState(() => _error = l10n.errorLoyaltyReason);
      return;
    }
    Navigator.of(context).pop((delta: delta, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('loyalty_adjust_dialog'),
      title: DialogHeader(
        icon: Icons.tune,
        title: l10n.loyaltyAdjust,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlateText(widget.plate),
            const SizedBox(height: Space.sm),
            Text(l10n.loyaltyVisitOf(widget.progress + 1, widget.required)),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('loyalty_adjust_delta'),
              controller: _delta,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
              ],
              decoration: InputDecoration(
                labelText: l10n.loyaltyAdjustDelta,
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('loyalty_adjust_reason'),
              controller: _reason,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.loyaltyAdjustReason,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('loyalty_adjust_save'),
          onPressed: _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
