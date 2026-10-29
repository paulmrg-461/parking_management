import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog_header.dart';
import '../../auth/domain/entities/user.dart';
import '../../lots/domain/entities/parking_lot.dart';
import '../domain/commands/create_user_command.dart';
import 'role_labels.dart';

final _pinPattern = RegExp(r'^\d{6}$');

/// Validated "new user" form (username, display name, 4–6 digit PIN, role).
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({
    super.key,
    required this.onCreate,
    this.lots = const [],
    this.initialLotId,
  });

  final void Function(CreateUserCommand command) onCreate;
  final List<ParkingLot> lots;
  final int? initialLotId;

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _role = UserRole.operator;
  int? _lotId;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lotId = widget.initialLotId ??
        (widget.lots.isEmpty ? null : widget.lots.first.id);
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.l10n.fieldRequired : null;

  String? _pin(String? value) =>
      _pinPattern.hasMatch((value ?? '').trim()) ? null : context.l10n.pinInvalid;

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.onCreate(
      CreateUserCommand(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        role: _role,
        pin: _pinController.text.trim(),
        lotId: _lotId,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: DialogHeader(icon: Icons.person_add_alt_1, title: l10n.userNew),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: l10n.loginUsername),
                autocorrect: false,
                autofocus: true,
                validator: _required,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(labelText: l10n.fieldDisplayName),
                textCapitalization: TextCapitalization.words,
                validator: _required,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.loginPin),
                validator: _pin,
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: InputDecoration(labelText: l10n.fieldRole),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label(l10n))),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              if (widget.lots.length > 1) ...[
                const SizedBox(height: Space.md),
                DropdownButtonFormField<int>(
                  initialValue: _lotId,
                  decoration: InputDecoration(labelText: l10n.lotLabel),
                  items: [
                    for (final lot in widget.lots)
                      DropdownMenuItem(value: lot.id, child: Text(lot.name)),
                  ],
                  onChanged: (value) => setState(() => _lotId = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionCreate)),
      ],
    );
  }
}
