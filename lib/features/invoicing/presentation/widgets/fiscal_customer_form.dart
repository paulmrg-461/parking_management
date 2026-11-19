import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/fiscal_customer.dart';
import '../../domain/entities/fiscal_settings.dart';

/// Optional "Datos para factura" section shared by the check-out and pass
/// payment dialogs. It only appears when invoicing is enabled.
class FiscalCustomerForm extends StatefulWidget {
  const FiscalCustomerForm({super.key, required this.config, this.onChanged});

  final FiscalConfig config;
  final ValueChanged<FiscalCustomer?>? onChanged;

  @override
  State<FiscalCustomerForm> createState() => FiscalCustomerFormState();
}

class FiscalCustomerFormState extends State<FiscalCustomerForm> {
  bool _open = false;
  FiscalIdType _type = FiscalIdType.cc;
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _error;

  bool get _empty =>
      _number.text.trim().isEmpty &&
      _name.text.trim().isEmpty &&
      _email.text.trim().isEmpty;

  FiscalCustomer? get customer {
    if (!_open || _empty) {
      return null;
    }
    final value = FiscalCustomer(
      documentType: _type,
      documentNumber: _number.text,
      name: _name.text,
      email: _email.text,
    );
    return value.isValid ? value.normalized() : null;
  }

  bool get isValid => !_open || _empty || customer != null;

  void _notify() {
    final value = customer;
    if (_open && value == null && !_empty) {
      setState(() => _error = context.l10n.fiscalInvalidCustomer);
    } else {
      setState(() => _error = null);
    }
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.enabled) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      key: const Key('fiscal_customer_form'),
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: const Key('fiscal_customer_toggle'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _open,
            onChanged: (value) {
              setState(() => _open = value ?? false);
              _notify();
            },
            title: Text(l10n.fiscalCustomerSection),
          ),
          if (_open) ...[
            DropdownButtonFormField<FiscalIdType>(
              key: const Key('fiscal_doc_type'),
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.fiscalDocType),
              items: [
                for (final type in FiscalIdType.values)
                  DropdownMenuItem(value: type, child: Text(type.wire)),
              ],
              onChanged: (value) {
                setState(() => _type = value ?? _type);
                _notify();
              },
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('fiscal_doc_number'),
              controller: _number,
              onChanged: (_) => _notify(),
              decoration: InputDecoration(labelText: l10n.fiscalDocNumber),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('fiscal_name'),
              controller: _name,
              onChanged: (_) => _notify(),
              decoration: InputDecoration(labelText: l10n.fiscalName),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('fiscal_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _notify(),
              decoration: InputDecoration(labelText: l10n.fiscalEmail),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Asks for the optional buyer data before issuing an invoice from the
/// history reprint. Returns null when the operator cancels.
Future<FiscalCustomer?> showFiscalCustomerDialog(
  BuildContext context, {
  required FiscalConfig config,
}) => showDialog<FiscalCustomer>(
  context: context,
  builder: (_) => _FiscalCustomerDialog(config: config),
);

class _FiscalCustomerDialog extends StatefulWidget {
  const _FiscalCustomerDialog({required this.config});

  final FiscalConfig config;

  @override
  State<_FiscalCustomerDialog> createState() => _FiscalCustomerDialogState();
}

class _FiscalCustomerDialogState extends State<_FiscalCustomerDialog> {
  final _key = GlobalKey<FiscalCustomerFormState>();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('fiscal_issue_dialog'),
      scrollable: true,
      title: Text(l10n.invoicingIssue),
      content: SizedBox(
        width: 420,
        child: FiscalCustomerForm(key: _key, config: widget.config),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('fiscal_issue_confirm'),
          onPressed: () {
            if (!(_key.currentState?.isValid ?? true)) {
              return;
            }
            Navigator.of(context).pop(_key.currentState?.customer);
          },
          child: Text(l10n.invoicingIssue),
        ),
      ],
    );
  }
}
