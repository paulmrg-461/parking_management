import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/cash_anomaly.dart';

/// Acknowledge (note optional) or dismiss (note required) one anomaly.
class AnomalyResolveDialog extends StatefulWidget {
  const AnomalyResolveDialog({
    super.key,
    required this.anomaly,
    required this.onResolve,
  });

  final CashAnomaly anomaly;
  final Future<void> Function(AnomalyStatus status, String? note) onResolve;

  @override
  State<AnomalyResolveDialog> createState() => _AnomalyResolveDialogState();
}

class _AnomalyResolveDialogState extends State<AnomalyResolveDialog> {
  final _note = TextEditingController();
  AnomalyStatus _status = AnomalyStatus.acknowledged;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.anomalyNoteLabel),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AnomalyStatus>(
            key: const Key('anomaly-resolve-status'),
            segments: [
              ButtonSegment(
                value: AnomalyStatus.acknowledged,
                label: Text(l10n.anomalyAcknowledge),
              ),
              ButtonSegment(
                value: AnomalyStatus.dismissed,
                label: Text(l10n.anomalyDismiss),
              ),
            ],
            selected: {_status},
            onSelectionChanged: _saving
                ? null
                : (selection) => setState(() => _status = selection.first),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('anomaly-note'),
            controller: _note,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.anomalyNoteLabel,
              helperText: l10n.anomalyNoteRequired,
            ),
          ),
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('anomaly-resolve-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionSave),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final note = _note.text.trim();
    if (_status == AnomalyStatus.dismissed && note.length < 3) {
      setState(() => _error = l10n.anomalyNoteRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onResolve(_status, note.isEmpty ? null : note);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
