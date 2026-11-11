import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../application/waitlist_cubit.dart';
import '../domain/entities/waitlist_settings.dart';

/// The three waitlist switches, for the lot admin only (`set_waitlist_settings`
/// refuses an operator server-side too).
class WaitlistSettingsDialog extends StatefulWidget {
  const WaitlistSettingsDialog({super.key, required this.initial});

  final WaitlistSettings? initial;

  @override
  State<WaitlistSettingsDialog> createState() => _WaitlistSettingsDialogState();
}

class _WaitlistSettingsDialogState extends State<WaitlistSettingsDialog> {
  late final _claim = TextEditingController(
    text: '${(widget.initial ?? WaitlistSettings.defaults).claimMinutes}',
  );
  late final _max = TextEditingController(
    text: '${(widget.initial ?? WaitlistSettings.defaults).maxEntries}',
  );
  late bool _enabled = (widget.initial ?? WaitlistSettings.defaults).enabled;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _claim.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: DialogHeader(
        icon: Icons.tune,
        title: l10n.waitlistSettingsTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('waitlist-settings-enabled'),
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: Text(l10n.waitlistSettingsEnabled),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            TextField(
              key: const Key('waitlist-settings-claim'),
              controller: _claim,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.waitlistSettingsClaimMinutes,
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('waitlist-settings-max'),
              controller: _max,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.waitlistSettingsMaxEntries,
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: Space.sm),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('waitlist-settings-save'),
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
    final claim = int.tryParse(_claim.text.trim());
    final max = int.tryParse(_max.text.trim());
    if (claim == null || claim < 5 || claim > 120) {
      setState(() => _error = l10n.errorInvalidData);
      return;
    }
    if (max == null || max < 1 || max > 500) {
      setState(() => _error = l10n.errorInvalidData);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await context.read<WaitlistCubit>().saveSettings(
      WaitlistSettings(
        enabled: _enabled,
        claimMinutes: claim,
        maxEntries: max,
      ),
    );
    if (!mounted) {
      return;
    }
    final state = context.read<WaitlistCubit>().state;
    final failed = state is WaitlistLoaded && state.submission is SubmissionFailed;
    if (failed) {
      final submission = state.submission;
      setState(() {
        _saving = false;
        _error = submission is SubmissionFailed
            ? l10n.failure(submission.failure!)
            : l10n.errorUnknown;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }
}
