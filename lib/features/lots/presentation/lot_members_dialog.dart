import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/entities/lot_member.dart';

class LotMembersDialog extends StatefulWidget {
  const LotMembersDialog({
    super.key,
    required this.lotName,
    required this.loadMembers,
    required this.onSetRole,
  });

  final String lotName;
  final Future<List<LotMember>> Function() loadMembers;
  final Future<bool> Function(LotMember member, String role) onSetRole;

  @override
  State<LotMembersDialog> createState() => _LotMembersDialogState();
}

class _LotMembersDialogState extends State<LotMembersDialog> {
  List<LotMember>? _members;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await widget.loadMembers();
    if (mounted) {
      setState(() => _members = members);
    }
  }

  Future<void> _change(LotMember member, String? role) async {
    if (role == null || role == member.role || _busy) {
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.onSetRole(member, role);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (ok) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = _members;
    return AlertDialog(
      title: Text(l10n.lotMembersTitle(widget.lotName)),
      content: SizedBox(
        width: 360,
        child: members == null
            ? const Padding(
                padding: EdgeInsets.all(Space.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            : members.isEmpty
            ? Text(l10n.lotMembersEmpty)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final member in members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.displayName),
                      subtitle: Text(
                        [
                          member.username,
                          if (!member.isActive) l10n.userInactive,
                        ].join(' · '),
                      ),
                      trailing: DropdownButton<String>(
                        value: member.role,
                        onChanged: _busy
                            ? null
                            : (role) => _change(member, role),
                        items: [
                          DropdownMenuItem(
                            value: 'operator',
                            child: Text(l10n.roleOperator),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(l10n.roleAdmin),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}
