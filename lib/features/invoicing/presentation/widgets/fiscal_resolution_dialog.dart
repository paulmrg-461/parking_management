import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/dialog_header.dart';
import '../../domain/entities/fiscal_resolution.dart';

/// Creates one numbering resolution (a new one deactivates the previous one of
/// the same type on the server).
Future<FiscalResolution?> showFiscalResolutionDialog(BuildContext context) =>
    showDialog<FiscalResolution>(
      context: context,
      builder: (_) => const _FiscalResolutionDialog(),
    );

class _FiscalResolutionDialog extends StatefulWidget {
  const _FiscalResolutionDialog();

  @override
  State<_FiscalResolutionDialog> createState() =>
      _FiscalResolutionDialogState();
}

class _FiscalResolutionDialogState extends State<_FiscalResolutionDialog> {
  FiscalDocType _type = FiscalDocType.pos;
  final _number = TextEditingController();
  final _prefix = TextEditingController();
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '5000');
  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 365));
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _prefix.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _validFrom : _validTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _validFrom = picked;
        } else {
          _validTo = picked;
        }
      });
    }
  }

  void _save() {
    final l10n = context.l10n;
    final rangeFrom = int.tryParse(_from.text.trim());
    final rangeTo = int.tryParse(_to.text.trim());
    if (_number.text.trim().isEmpty ||
        rangeFrom == null ||
        rangeTo == null ||
        rangeFrom <= 0 ||
        rangeTo < rangeFrom ||
        _validTo.isBefore(_validFrom) ||
        !RegExp(r'^[A-Za-z0-9]{0,6}$').hasMatch(_prefix.text.trim())) {
      setState(() => _error = l10n.errorInvalidData);
      return;
    }
    Navigator.of(context).pop(
      FiscalResolution(
        docType: _type,
        resolutionNumber: _number.text.trim(),
        prefix: _prefix.text.trim(),
        rangeFrom: rangeFrom,
        rangeTo: rangeTo,
        validFrom: _validFrom,
        validTo: _validTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('fiscal_resolution_dialog'),
      scrollable: true,
      title: DialogHeader(
        icon: Icons.confirmation_number_outlined,
        title: l10n.invoicingResolutionAdd,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<FiscalDocType>(
              key: const Key('fiscal_resolution_type'),
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.fiscalDocType),
              items: [
                for (final type in FiscalDocType.values)
                  DropdownMenuItem(value: type, child: Text(type.wire)),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('fiscal_resolution_number'),
              controller: _number,
              decoration: InputDecoration(
                labelText: l10n.invoicingResolutions,
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('fiscal_resolution_prefix'),
              controller: _prefix,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Prefijo'),
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fiscal_resolution_from'),
                    controller: _from,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Desde'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextField(
                    key: const Key('fiscal_resolution_to'),
                    controller: _to,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Hasta'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton(
                  onPressed: () => _pick(from: true),
                  child: Text(_date(_validFrom)),
                ),
                OutlinedButton(
                  onPressed: () => _pick(from: false),
                  child: Text(_date(_validTo)),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          key: const Key('fiscal_resolution_save'),
          onPressed: _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
