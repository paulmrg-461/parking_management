import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/fare/fare_adjustment.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../check_out/domain/entities/check_out_preview.dart';
import '../domain/entities/merchant.dart';

/// What the check-out dialog needs to add/remove an agreement.
class MerchantDeskOptions {
  const MerchantDeskOptions({
    required this.options,
    required this.apply,
    this.revoke,
  });

  final List<Merchant> options;

  /// Adds the validation and returns the refreshed preview.
  final Future<CheckOutPreview> Function(int merchantId) apply;

  /// Removes a pending validation and returns the refreshed preview.
  final Future<CheckOutPreview> Function(int validationId, String reason)?
      revoke;
}

/// Collapsible "Convenio" block of the settlement dialog.
class DeskMerchantSection extends StatefulWidget {
  const DeskMerchantSection({
    super.key,
    required this.merchants,
    required this.preview,
    required this.onChanged,
    this.canRevoke = false,
  });

  final MerchantDeskOptions merchants;
  final CheckOutPreview? preview;
  final ValueChanged<CheckOutPreview> onChanged;
  final bool canRevoke;

  @override
  State<DeskMerchantSection> createState() => _DeskMerchantSectionState();
}

class _DeskMerchantSectionState extends State<DeskMerchantSection> {
  int? _selected;
  bool _busy = false;

  List<FareAdjustment> get _lines => [
    for (final line in widget.preview?.quote?.adjustments ?? const [])
      if (line.type == FareAdjustmentType.merchant) line,
  ];

  Future<void> _apply() async {
    final merchantId = _selected;
    if (merchantId == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final preview = await widget.merchants.apply(merchantId);
      widget.onChanged(preview);
      if (mounted) {
        setState(() => _selected = null);
      }
    } on Failure catch (failure) {
      if (mounted) {
        showErrorSnack(context, context.l10n.failure(failure));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke(FareAdjustment line) async {
    final revoke = widget.merchants.revoke;
    if (revoke == null) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RevokeReasonDialog(),
    );
    if (reason == null || !mounted) {
      return;
    }
    try {
      final preview = await revoke(line.refId, reason);
      widget.onChanged(preview);
    } on Failure catch (failure) {
      if (mounted) {
        showErrorSnack(context, context.l10n.failure(failure));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final available = [
      for (final merchant in widget.merchants.options)
        if (!_lines.any((line) => line.label == merchant.name)) merchant,
    ];
    return ExpansionTile(
      key: const Key('desk_merchant_section'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.deskMerchantTitle),
      subtitle: _lines.isEmpty
          ? null
          : Text(
              _lines.map((line) => line.label).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      children: [
        for (final line in _lines)
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 18),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(l10n.fareAdjustmentMerchant(line.label)),
              ),
              Text('-${Money.format(line.amount)}'),
              if (widget.canRevoke)
                IconButton(
                  tooltip: l10n.deskMerchantRevoke,
                  onPressed: () => unawaited(_revoke(line)),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          DropdownButtonFormField<int>(
            key: const Key('desk_merchant_pick'),
            isExpanded: true,
            initialValue: _selected,
            decoration: InputDecoration(labelText: l10n.deskMerchantPick),
            items: [
              for (final merchant in available)
                DropdownMenuItem(
                  value: merchant.id,
                  child: Text(merchant.name),
                ),
            ],
            onChanged: (value) => setState(() => _selected = value),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            key: const Key('desk_merchant_apply'),
            onPressed: _busy || _selected == null ? null : _apply,
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l10n.deskMerchantApply),
          ),
        ],
      ],
    );
  }
}

/// The reason prompt owns its controller, so the dialog animation never uses a
/// disposed one.
class _RevokeReasonDialog extends StatefulWidget {
  const _RevokeReasonDialog();

  @override
  State<_RevokeReasonDialog> createState() => _RevokeReasonDialogState();
}

class _RevokeReasonDialogState extends State<_RevokeReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.deskMerchantRevoke),
    content: TextField(
      key: const Key('desk_merchant_reason'),
      controller: _controller,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: context.l10n.deskMerchantRevokeReason,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.actionCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: Text(context.l10n.actionConfirm),
      ),
    ],
  );
}
